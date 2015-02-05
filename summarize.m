#import <Foundation/Foundation.h>

NSDictionary *parseFactorsFile(NSURL *fileURL);
NSArray *parseReportFile(NSURL *fileURL);
NSArray *getLinesOfTabFile(NSURL *fileURL);

static NSString * const ExchangeFactorKey = @"exchangeFactor";
static NSString * const WithholdingTaxFactorKey = @"withholdingTaxFactor";

static NSString * const AppIDKey = @"Apple Identifier";
static NSString * const CurrencyKey = @"Partner Share Currency";
static NSString * const EarningsKey = @"Partner Share";
static NSString * const StartDateKey = @"Start Date";
static NSString * const EndDateKey = @"End Date";
static NSString * const QuantityKey = @"Quantity";

@interface NSDecimalNumber (abs)
- (NSDecimalNumber *)absoluteValue;
@end

@interface NSString (decimalNumber)
- (NSString *)cleanUpDecimalNumber;
@end

int main(int argc, char *argv[]) {
	@autoreleasepool {
		
		NSString *folderPath = nil;
		NSString *reportsFolderName = nil;
		NSString *headFilename = nil;
		NSString *tailFilename = nil;
		
		for (int i = 0; i <= 3; i++) {
			if (!argv[i]) {
				break;
			}
			NSString *argument = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
			switch (i) {
				case 0:
					folderPath = [argument stringByDeletingLastPathComponent];
					break;
				case 1: 
					reportsFolderName = argument;
					break;
				case 2:
					headFilename = argument;
					break;
				case 3:
					tailFilename = argument;
					break;
			}
		}

		if (!reportsFolderName || !headFilename || !tailFilename) {
			NSLog(@"Missing argument! Required arguments (in this order): folder name, head file, tail file");
			return 0;
		}
		
		NSString *reportsFolderPath = [folderPath stringByAppendingPathComponent:reportsFolderName];
		NSDirectoryEnumerator *reportsFolderEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:reportsFolderPath isDirectory:YES] includingPropertiesForKeys:nil options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:nil];
		
		NSDictionary *factors = nil;
		NSMutableArray *reports = [NSMutableArray array];
		NSURL *fileURL = nil;
		while (fileURL = [reportsFolderEnumerator nextObject]) {
			if ([fileURL.pathExtension isEqualToString:@"txt"]) {
				
				if ([fileURL.lastPathComponent hasPrefix:@"factors"]) {
					factors = parseFactorsFile(fileURL);
				} else {
					NSArray *report = parseReportFile(fileURL);
					if (report) {
						[reports addObject:report];
					}
				}
				
			}
		}
		
		if (!factors || factors.count == 0) {
			NSLog(@"Factors file missing!");
			return 0;
		}
		
		__block NSMutableString *body = nil;
		__block double totalEarnings = 0;
		
		[reports enumerateObjectsUsingBlock:^(NSArray *report, NSUInteger reportIndex, BOOL *stop) {
			[report enumerateObjectsUsingBlock:^(NSDictionary *sale, NSUInteger saleIndex, BOOL *stop) {
				if (!body) {
					NSDateFormatter *itcDateFormatter = [NSDateFormatter new];
					itcDateFormatter.dateFormat = @"MM/dd/yyyy";
					NSDate *startDate = [itcDateFormatter dateFromString:sale[StartDateKey]];
					NSDate *endDate = [itcDateFormatter dateFromString:sale[EndDateKey]];
					NSDateFormatter *germanDateFormatter = [NSDateFormatter new];
					germanDateFormatter.dateStyle = NSDateFormatterShortStyle;
					germanDateFormatter.timeStyle = NSDateFormatterNoStyle;
					
					NSString *headFilePath = [folderPath stringByAppendingPathComponent:headFilename];
					body = [NSMutableString stringWithContentsOfFile:headFilePath usedEncoding:NULL error:nil];
					if (!body) {
						NSLog(@"Error reading head file: %@!", headFilePath);
						body = [NSMutableString string];
					}
					
					[body appendFormat:@"\n####**Rechnungszeitraum: %@ - %@**\n\n", [germanDateFormatter stringFromDate:startDate], [germanDateFormatter stringFromDate:endDate]];
					[body appendString:@"| Produkt ID | Preis | Stückzahl | Umrechnungsfaktor | Gesamtpreis |\n| --- | --- | --- | --- | --- |\n"];
				}
				
				NSDecimalNumber *exchangeFactor = factors[sale[CurrencyKey]][ExchangeFactorKey];
				NSDecimalNumber *withholdingTaxFactor = factors[sale[CurrencyKey]][WithholdingTaxFactorKey];
				
				double total = [sale[EarningsKey] doubleValue]*[sale[QuantityKey] integerValue]*exchangeFactor.doubleValue*withholdingTaxFactor.doubleValue;
				totalEarnings += total;
				
				NSString *currency = sale[CurrencyKey];
				if ([currency isEqualToString:@"USD - RoW"]) { // USD for Rest of World should appear as normal USD (but other factors)
					currency = @"USD";
				}
				
				[body appendFormat:@"| %@ | %@ %@ | %@ | %@ | %.2f EUR |\n", sale[AppIDKey], sale[EarningsKey], currency, sale[QuantityKey], exchangeFactor, total];
			}];
		}];
		
		[body appendFormat:@"\n####**Gesamt: %.2f EUR**\n\n", totalEarnings];
		NSString *tailFilePath = [folderPath stringByAppendingPathComponent:tailFilename];
		NSString *tail = [NSString stringWithContentsOfFile:tailFilePath usedEncoding:NULL error:nil];
		if (!tail) {
			NSLog(@"Error reading tail file: %@!", tailFilePath);
			return 0;
		}
		[body appendString:tail];
			
		NSError *billWritingError = nil;
		[body writeToFile:[folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"iTunes Connect Bill %@.md", reportsFolderName]] atomically:YES encoding:NSUTF8StringEncoding error:&billWritingError];
		if (billWritingError) {
			NSLog(@"Error writing bill to disk: %@", billWritingError);
		}
	}
}

NSDictionary *parseFactorsFile(NSURL *fileURL) {
	NSArray *lines = getLinesOfTabFile(fileURL);
	if (!lines) {
		return nil;
	}
	
	NSMutableDictionary *factors = [NSMutableDictionary dictionary];
	[lines enumerateObjectsUsingBlock:^(NSArray *lineComponents, NSUInteger idx, BOOL *stop) {
		NSString *currency = lineComponents[0];
		NSDecimalNumber *subtotal = [NSDecimalNumber decimalNumberWithString:[lineComponents[3] cleanUpDecimalNumber]];
		NSDecimalNumber *withholdingTax = [NSDecimalNumber decimalNumberWithString:[lineComponents[4] cleanUpDecimalNumber]];
		NSDecimalNumber *exchangeFactor = [NSDecimalNumber decimalNumberWithString:[lineComponents[8] cleanUpDecimalNumber]];
		NSDecimalNumber *withholdingTaxFactor = [[NSDecimalNumber one] decimalNumberBySubtracting:[[withholdingTax decimalNumberByDividingBy:subtotal] absoluteValue]];
		factors[currency] = @{ ExchangeFactorKey: exchangeFactor, WithholdingTaxFactorKey: withholdingTaxFactor };
	}];
	
	return [factors copy];
}

NSArray *parseReportFile(NSURL *fileURL) {
	NSArray *lines = getLinesOfTabFile(fileURL);
	if (!lines) {
		return nil;
	}
	
	NSString *area = [[fileURL lastPathComponent] stringByDeletingPathExtension];
	area = [area substringWithRange:NSMakeRange(area.length-2, 2)];
	NSMutableArray *report = [NSMutableArray array];
	NSArray *columns = [lines firstObject];
	[lines enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, lines.count-1)] options:kNilOptions usingBlock:^(NSArray *lineComponents, NSUInteger idx, BOOL *stop) {
		NSMutableDictionary *sale = [NSMutableDictionary dictionary];
		[columns enumerateObjectsUsingBlock:^(NSString *column, NSUInteger idx, BOOL *stop) {
			sale[column] = lineComponents[idx];
		}];
		if ([area isEqualToString:@"WW"]) {
			sale[CurrencyKey] = @"USD - RoW";
		}
		[report addObject:[sale copy]];
	}];
	
	return [report copy];
}

NSArray *getLinesOfTabFile(NSURL *fileURL) {
	NSError *fileReadingError = nil;
	NSString *tabDelimitedReport = [NSString stringWithContentsOfURL:fileURL usedEncoding:NULL error:&fileReadingError];
	if (fileReadingError) {
		NSLog(@"Error reading file(%@): %@", fileURL, fileReadingError);
		return nil;
	}
	
	// parse txt file
	NSArray *rawLines = [tabDelimitedReport componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	if (!rawLines || rawLines.count == 0) {
		NSLog(@"Empty file!");
		return nil;
	}
	
	NSMutableArray *parsedLines = [NSMutableArray array];
	[rawLines enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop){
		NSArray *line = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\t"]];
		if (!line || line.count == 0 || (idx > 0 && line.count != [parsedLines[0] count])) {
			return;
		}
		[parsedLines addObject:line];
	}];
	if (parsedLines.count == 0) {
		return nil;
	}

	return [parsedLines copy];
}

@implementation NSDecimalNumber (abs)

- (NSDecimalNumber *)absoluteValue {
	if ([self compare:[NSDecimalNumber zero]] == NSOrderedAscending) {
		NSDecimalNumber *negativeOne = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:0 isNegative:YES];
		return [self decimalNumberByMultiplyingBy:negativeOne];
	} else {
		return self;
	}
}

@end

@implementation NSString (decimalNumber)

- (NSString *)cleanUpDecimalNumber {
	return [self stringByReplacingOccurrencesOfString:@"," withString:@""];
}

@end