### Generate Bills from Apples Financial Reports
Apple generates financial reports in txt format. The German tax office wants to see bills. This program helps you to generate bills from the financial reports.

### Important Note
Use this at your own risk. I am not responsible for any lost data on your machine. You should create a directory for your financial reports and run the program in that directory.

Creating bills for the tax office with this program works for me. Before you submit the bills you should check them with your tax consultant! I am not responsible for any problems you have with your tax office because of this program.

### How it works
Read the Imortant Note. Read it again!

Create a directory for every month. Let's say you want to generate the bills for December 2014. You could do this:

```
$ cd ~/Documents
$ mkdir financial_reports; cd financial_reports
$ mkdir 1214; cd 1214
```

Download all financial reports from iTunes Connect for this month into that directory.

Copy the exchange rates from "iTunes Connect > Payments & Financial Reports > Payments" for this month and paste them in a file called "factors.txt". Put this file into the directory with your reports (1214/ in the example). It should look like this:

```
CHF	0.00	1.30	1.30	0.00	0.00	0.00	1.30	0.99231	1.29	EUR
EUR	0.00	10.60	10.60	0.00	0.00	0.00	10.60	1.00000	10.60	EUR
GBP	0.00	4.54	4.54	0.00	0.00	0.00	4.54	1.33260	6.05	EUR
IDR	0.00	8,400.00	8,400.00	0.00	0.00	0.00	8,400.00	0.00007	0.59	EUR
ILS	0.00	4.83	4.83	0.00	0.00	0.00	4.83	0.22360	1.08	EUR
JPY	0	1,750	1,750	-358	0	0	1,392	0.00750	10.44	EUR
NOK	0.00	10.64	10.64	0.00	0.00	0.00	10.64	0.11372	1.21	EUR
TWD	0.00	42.00	42.00	0.00	0.00	0.00	42.00	0.02905	1.22	EUR
USD	0.00	52.50	52.50	0.00	0.00	0.00	52.50	0.88819	46.63	EUR
USD - RoW	0.00	1.40	1.40	0.00	0.00	0.00	1.40	0.88571	1.24	EUR
```

Enter your name and address in head.md: Open head.md with your favorite markdown editor and replace the template name/adress/vat. Then do:

```
$ cd ~/Documents/financial_reports
$ ./summarize 1214 head.md tail.md
```

Now you should have a file called "iTunes Connect Bill 1214.md" in this directory. 
Done.

### Compatibility
You can open and compile the summarize.m file in e.g. [CodeRunner](https://coderunnerapp.com), though you don’t need to as the executable is already in this repo. The program makes use of ARC, so make sure your compile flags look like:
```
-fobjc-arc -framework Foundation
```

### Acknowledgement
This ObjC program is based on a [perl script](https://github.com/dasdom/CreateAppStoreBill) written by [@dasdom](https://github.com/dasdom). Thanks so much Dominik!