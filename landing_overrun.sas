/*############################################################################################
Import data and combine multiple files*/
PROC IMPORT DATAFILE = "/home/jagarlka0/sasuser.v94/Mid-Term Project/FAA1.xls" OUT = faa1 replace dbms=xls;
SHEET = "FAA1"; GETNAMES = yes;
RUN;
PROC IMPORT DATAFILE = "/home/jagarlka0/sasuser.v94/Mid-Term Project/FAA2.xls" OUT = faa2 replace dbms=xls;
SHEET = "FAA2"; GETNAMES = yes;
RUN;


/*############################################################################################
Clean the table - Remove blank rows
manual observation of data sets showed that faa2.xls has blank rows at the end*/
options missing = ' ';
data faa2;
   set faa2;
   if missing(cats(of _all_)) then delete;
run;


/*############################################################################################
Merge two tables by the column names. Manual observation of data shows two things-
1) The second data set has only 7 variables compared to 8 in the first
2) Some rows in the second dataset have same values as the first, except of course for the missing variable*/
proc sort data=faa1;
by aircraft no_pasg speed_ground speed_air height pitch distance;
run;
proc sort data=faa2;
by aircraft no_pasg speed_ground speed_air height pitch distance;
run;
data faa;
merge faa1 faa2;
by aircraft no_pasg speed_ground speed_air height pitch distance;
label aircraft='Aircraft Company' no_pasg='Number of Passengers' speed_ground='Ground Speed' speed_air='Air Speed' height='Landing Height' pitch='Landing Pitch' distance='Landing Distance';
run;


/*############################################################################################
Find empty values for each variables*/
proc means data=faa n nmiss mean median;
run;
/*Above proc showed distance and air speed variables have missing values.*/


/*############################################################################################
Find abnormal values in each variables*/

/*Duration - a normal flight duration is grater than 40 min
Ground Speed - must be between 30 mph and 140 mph
Air Speed - must be between 30 mph and 140 mph
Height - must be greater than 6 m
Distance - Normally less than 6000 ft. */
data faa_abnormal;
set faa;
if duration=. then duration_abnormal='missing'; /*We know this variable has missing values*/
else if duration<40 then duration_abnormal='abnormal';
else duration_abnormal='normal';
label duration_abnormal = 'Duration';
if speed_ground<30 or speed_ground>140 then sp_gr_abnormal='abnormal';
else sp_gr_abnormal='normal';
label sp_gr_abnormal = 'Ground Speed';
if speed_air=. then sp_air_abnormal='missing'; /*We know this variable has missing values*/
else if speed_air<30 or speed_air>140 then sp_air_abnormal='abnormal';
else sp_air_abnormal='normal';
label sp_air_abnormal = 'Air Speed';
if height<6 then height_abnormal='abnormal';
else height_abnormal='normal';
label height_abnormal = 'Height';
if distance>6000 then distance_abnormal='abnormal';
else distance_abnormal='normal';
label distance_abnormal = 'Distance';
/*Consolidate missing and abnormal value columns*/
if duration_abnormal='missing' or sp_air_abnormal='missing' then missing_val='missing';
else missing_val='no missing values';
if duration_abnormal='abnormal' or sp_gr_abnormal='abnormal' or sp_air_abnormal='abnormal' or height_abnormal='abnormal' or distance_abnormal='abnormal' then abnormal_val='abnormal';
else abnormal_val='normal';
if missing_val='missing' or abnormal_val='abnormal' then row_clean='unclean';
else row_clean='clean';
run;


/*############################################################################################
Observe missing values and abnormal values in each variable*/
proc freq data=faa_abnormal;
title 'Missing or abnormal values in each variable';
tables duration_abnormal sp_gr_abnormal sp_air_abnormal height_abnormal distance_abnormal /nocum nopercent nocol;
run;
/*Find impact of missing data or abnormal values*/
proc freq data=faa_abnormal;
title 'Impact of above missing or abnormal values on quality of data';
tables abnormal_val missing_val row_clean /nocum nopercent nocol;
run;


/*############################################################################################
Removing the unclean rows of the data. Also remove temporary variables created in previous steps*/
data faa_clean;
set faa_abnormal;
if abnormal_val='abnormal' then delete;
drop duration_abnormal sp_gr_abnormal sp_air_abnormal height_abnormal distance_abnormal abnormal_val missing_val row_clean;
run;


/*############################################################################################
Observe each variable*/
/*Airline*/
proc freq data=faa_clean;
title 'Number of aircraft from each of the airline companies';
tables aircraft /nocum nopercent;
run;

title ;
proc univariate data=faa_clean noprint;
var duration height speed_air speed_ground no_pasg pitch distance;
histogram /kernel normal(noprint);
inset n nmiss mean std min max normal(ksdpval)skewness kurtosis/position=ne;
run;


/*############################################################################################
Create dummy variable for character column - aircraft*/
data faa_clean;
set faa_clean;
if aircraft='boeing' then aircraft_num=0;
else aircraft_num=1;

/*############################################################################################
Observe plot of each variable with landing distance to understand distribution*/
proc plot data = faa_clean;
plot distance*pitch;
plot distance*height;
plot distance*speed_air;
plot distance*speed_ground;
plot distance*no_pasg;
plot distance*duration;
run;

proc means mean std min max;
class aircraft;
var distance;
run;

/*############################################################################################
Observe correlation between all the variables*/
proc corr data = faa_clean;
var distance duration height speed_air speed_ground no_pasg pitch aircraft_num;
run;
/*Above proc shows air speed variable is highly correlated with ground speed.
Since it has too many missing values, it is being dropped. It's impact/significance can be gathered from ground speed*/
data faa_clean;
set faa_clean;
drop speed_air;
run;

/*############################################################################################
Begin the model building using proc reg*/
proc reg data=faa_clean;
model distance= duration height speed_ground no_pasg pitch aircraft_num;
run;

/*Above proc showed that the three variables duration, no_pasg and pitch are not significant.
These variables all have very low corelation among themselves as seen in proc corr output
Hence removing all of them at once from the regression procedure*/
proc reg data=faa_clean;
model distance= height speed_ground aircraft_num;
output out=faa_res r=residuals;
run;

/*############################################################################################
Checking assumptions on residuals*/
/*Check for normality of residuals*/
proc univariate data=faa_res noprint;
var residuals;
histogram /kernel normal(noprint);
inset n nmiss mean std min max normal(ksdpval)skewness kurtosis/position=ne;
run;

/*Check for zero mean of residuals*/
proc means data=faa_res mean prt;
var residuals;
run;

