FILENAME REFFILE '/home/jrasmusvorrath0/energydata_complete.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=PCR_energy;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=PCR_energy; RUN;

proc print data = PCR_energy; run;



*Data Cleaning: Formatting variable types;

proc contents data=PCR_energy out=vars(keep=name type) noprint; 

data vars; set vars;                                                 
if type=2 and name ne 'date';                               
newname=trim(left(name))||"_n";                                                                               

options symbolgen;                                        

proc sql noprint;                                         
select trim(left(name)), trim(left(newname)),             
       trim(left(newname))||'='||trim(left(name))         
into :c_list separated by ' ', :n_list separated by ' ',  
     :renam_list separated by ' '                         
from vars;                                                
quit;                                                                                                               

data PCR_energy2; set PCR_energy;                                                 
array ch(*) $ &c_list;                                    
array nu(*) &n_list;                                      
do i = 1 to dim(ch);                                      
  nu(i)=input(ch(i),8.);                                  
end;                                                      
drop i &c_list;                                           
rename &renam_list;                                                                                      
run; 

proc contents data = PCR_energy2; run;

data PCR_energy3; set PCR_energy2;
*Convert the character string to SAS datetime value;
datetime =input(date, anydtdtm19.);
*Apply format to the SAS date time value;
format datetime dateampm17.;		*to convert to seconds, use anydtdtm19. as format;
drop date;								*to convert to numeric date, use dateampm17. format;
run;

proc contents data = PCR_energy3; run;


proc means data = PCR_energy3 n min q1 median mean q3 max range nmiss std var kurt skew;
run;


*EDA: Exploring variable distributions and relationships;

proc sgscatter data= PCR_energy3;
matrix Appliances lights T1 RH_1 T2 RH_2 T3 RH_3 T4 / 
	ellipse diagonal=(histogram normal) markerattrs = (color = orange) transparency=0.8;
run;

proc sgscatter data= PCR_energy3;
matrix Appliances lights RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 / 
	ellipse diagonal=(histogram normal) markerattrs = (color = orange) transparency=0.8;
run;

proc sgscatter data= PCR_energy3;
matrix Appliances lights T9 RH_9 T_out Press_mm_hg RH_out Windspeed Visibility Tdewpoint / 
	ellipse diagonal=(histogram normal) markerattrs =(color = orange) transparency=0.8;
run;



proc corr data= PCR_energy3 outp = corr(where=(_type_='CORR')) noprint;
run;

proc transpose data=corr(rename=(_name_=RowLab))
	out=t(rename=(col1=Value _name_=ColLab));
by notsorted rowlab;
run;

data t2; length v $ 5; set t;
v = ifc(-1e-8 le value le 1e-8, ' 0', ifc(rowlab eq collab, ' ---', put(value, 5.2)));
AbsValue = ifn(rowlab eq collab, 0, abs(value));
run;

ods graphics on / height=9in width=9in;

proc sgplot noautolegend;
title h=7pt 'Correlation Heatmap';
heatmapparm y=rowlab x=collab colorresponse= absvalue / colormodel=(cxFAFBFE cx667FA2 cxD05B5B);
text y=rowlab x=collab text=v;
%let opts = display=(nolabel noticks) valueattrs=(size=7) offsetmin=0.05 offsetmax=0.05;
xaxis &opts;
yaxis &opts reverse;
run;

title;



PROC SQL;
create table T_data as 
select * from 
(SELECT t1 as TVal, 'T1' as Name FROM PCR_energy3
union
SELECT t2 as TVal, 'T2' as Name FROM PCR_energy3
union
SELECT t3 as TVal, 'T3' as Name FROM PCR_energy3
union
SELECT t4 as TVal, 'T4' as Name FROM PCR_energy3
union
SELECT t5 as TVal, 'T5' as Name FROM PCR_energy3
union
SELECT t6 as TVal, 'T6' as Name FROM PCR_energy3
union
SELECT t7 as TVal, 'T7' as Name FROM PCR_energy3
union
SELECT t8 as TVal, 'T8' as Name FROM PCR_energy3
union
SELECT t9 as TVal, 'T9' as Name FROM PCR_energy3) as T_data order by name;
QUIT;

proc sgplot data= T_data;
vbox TVal / category= Name;
run;

PROC SQL;
create table RH_data as 
select * from 
(SELECT rh_1 as RHVal, 'RH_1' as Name FROM PCR_energy3
union
SELECT rh_2 as RHVal, 'RH_2' as Name FROM PCR_energy3
union
SELECT rh_3 as RHVal, 'RH_3' as Name FROM PCR_energy3
union
SELECT rh_4 as RHVal, 'RH_4' as Name FROM PCR_energy3
union
SELECT rh_5 as RHVal, 'RH_5' as Name FROM PCR_energy3
union
SELECT rh_6 as RHVal, 'RH_6' as Name FROM PCR_energy3
union
SELECT rh_7 as RHVal, 'RH_7' as Name FROM PCR_energy3
union
SELECT rh_8 as RHVal, 'RH_8' as Name FROM PCR_energy3
union
SELECT rh_9 as RHVal, 'RH_9' as Name FROM PCR_energy3) as RH_data order by name;
QUIT;

proc sgplot data= RH_data;
vbox RHVal / category= Name;
run;



*Horizontal sum to create single energy parameter as response variable (log-transformed);

data PCR_energy4; set PCR_energy3;
Energy = Appliances + lights;
log_Energy = log(Energy);
run;



*EDA: identifying most significant higher-order variable relationships;

/* 
proc glmselect data = PCR_energy4 plots(stepAxis=number)=(criterionPanel ASEPlot);
partition fraction(validate=0.5);
model Energy = datetime|Press_mm_hg|RH_1|RH_2|RH_3|RH_4|RH_5|RH_6|RH_7|RH_8|RH_9|RH_out|
						T1|T2|T3|T4|T5|T6|T7|T8|T9|T_out|Tdewpoint|
						Visibility|Windspeed|lights|rv1|rv2 @3
						/ selection= stepwise(choose = validate select = sl) hierarchy = single; 
run;
*/

/*
data PCR_energy5; set PCR_energy4;
RH_Int_1_2 = RH_1*RH_2;
RH_Int_1_3 = RH_1*RH_3;
RH_Int_2_3 = RH_2*RH_3;
RH_Int_1_6 = RH_1*RH_6;
RH_Int_2_6 = RH_2*RH_6;
RH_Int_3_7 = RH_3*RH_7;
RH_Int_2_8 = RH_2*RH_8;
RH_Int_6_out = RH_6*RH_out;
RH_Int_4_T1 = RH_4*T1;
RH_Int_6_T1 = RH_6*T1;
RH_Int_1_T2 = RH_1*T2;
RH_Int_2_T2 = RH_2*T2;
RH_Int_4_T2 = RH_4*T2;
RH_Int_6_T2 = RH_6*T2;
RH_Int_8_T2 = RH_8*T2;
RH_Int_out_T2 = RH_out*T2;
T_Int_1_2 = T1*T2;
RH_Int_3_T3 = RH_3*T3;
RH_Int_4_T3 = RH_4*T3;
RH_Int_6_T3 = RH_6*T3;
RH_Int_1_T6 = RH_1*T6;
T_Int_3_6 = T3*T6;
RH_Int_2_T8 = RH_2*T8;
RH_Int_3_T8 = RH_3*T8;
RH_Int_8_T8 = RH_8*T8;
T_Int_4_8 = T4*T8;
RH_Int_2_T9 = RH_2*T9;
RH_Int_3_T9 = RH_3*T9;
RH_Int_4_T9 = RH_4*T9;
RH_Int_6_T9 = RH_6*T9;
RH_Int_7_T9 = RH_7*T9;
T_Int_2_9 = T2*T9;
T_Int_3_9 = T3*T9;
T_Int_8_9 = T8*T9;
RH_Int_4_T_out = RH_4*T_out;
RH_Int_3_Windspeed = RH_3*Windspeed;
T_Int_6_Windspeed = T6*Windspeed;
T_Int_9_Windspeed = T9*Windspeed;
run;

data PCR_energy6; set PCR_energy5;
RH_Int_1_2_6 = RH_1*RH_2*RH_6;
RH_Int_2_8_T2 = RH_2*RH_8*T2;
RH_Int_1_T1_T2 = RH_1*T1*T2;
RH_Int_3_T3_T4 = RH_3*T3*T4;
RH_Int_6_T2_T6 = RH_6*T2*T6;
RH_Int_out_T2_T6 = RH_out*T2*T6;
RH_Int_out_T6_T8 = RH_out*T6*T8;
RH_Int_1_2_T9 = RH_1*RH_2*T9;
RH_Int_1_6_T9 = RH_1*RH_6*T9;
RH_Int_2_6_T9 = RH_2*RH_6*T9;
RH_2_T2_T9 = RH_2*T2*T9;
T_Int_3_6_9 = T3*T6*T9;
RH_Int_2_T8_T9 = RH_2*T8*T9;
RH_Int_8_T8_T9 = RH_8*T8*T9;
T_Int_6_8_9 = T6*T8*T9;
RH_Int_out_T6_Windspeed = RH_out*T6*Windspeed;
T_Int_3_6_Windspeed = T3*T6*Windspeed;
run;
*/



*PCA with 15 PCs --> .1898 Adjusted R^2;

proc princomp plots=all  data=PCR_energy4 out= PCR n = 15;
var datetime Press_mm_hg RH_1 RH_2 RH_3 RH_4 RH_5 RH_6 RH_7 RH_8 RH_9 RH_out
						T1 T2 T3 T4 T5 T6 T7 T8 T9 T_out Tdewpoint
						Visibility Windspeed rv1 rv2
/*						
						RH_Int_1_2 RH_Int_1_3 RH_Int_2_3 RH_Int_1_6 RH_Int_2_6 RH_Int_3_7
						RH_Int_2_8 RH_Int_6_out RH_Int_4_T1 RH_Int_6_T1 RH_Int_1_T2 RH_Int_2_T2
						RH_Int_4_T2 RH_Int_6_T2 RH_Int_8_T2 RH_Int_out_T2 T_Int_1_2 RH_Int_3_T3 
						RH_Int_4_T3 RH_Int_6_T3 RH_Int_1_T6 T_Int_3_6 RH_Int_2_T8 RH_Int_3_T8 
						RH_Int_8_T8 T_Int_4_8 RH_Int_2_T9 RH_Int_3_T9 RH_Int_4_T9 RH_Int_6_T9
						RH_Int_7_T9 T_Int_2_9 T_Int_3_9 T_Int_8_9 RH_Int_4_T_out RH_Int_3_Windspeed
						T_Int_6_Windspeed T_Int_9_Windspeed
						
						RH_Int_1_2_6 RH_Int_2_8_T2 RH_Int_1_T1_T2 RH_Int_3_T3_T4 RH_Int_6_T2_T6
						RH_Int_out_T2_T6 RH_Int_out_T6_T8 RH_Int_1_2_T9 RH_Int_1_6_T9 RH_Int_2_6_T9
						RH_2_T2_T9 T_Int_3_6_9 RH_Int_2_T8_T9 RH_Int_8_T8_T9 T_Int_6_8_9 
						RH_Int_out_T6_Windspeed T_Int_3_6_Windspeed
*/
;
run;
      
proc reg data= PCR plots = all;
model Energy = Prin1-Prin15;
run;

*Improved Performance with log-transformation of right-skewed Energy variable;

proc reg data = PCR plots = all;
model log_Energy = Prin1-Prin15;
run;



*PCA with all PCs --> .2562 Adjusted R^2;

proc princomp plots=all  data=PCR_energy4 out= PCR_2 n = 27;
var datetime Press_mm_hg RH_1 RH_2 RH_3 RH_4 RH_5 RH_6 RH_7 RH_8 RH_9 RH_out
						T1 T2 T3 T4 T5 T6 T7 T8 T9 T_out Tdewpoint
						Visibility Windspeed rv1 rv2;
run;

proc reg data = PCR_2 plots = all;
model log_Energy = Prin1-Prin27;
run;



*Comparison with PROC REG output --> .2562 Adjusted R^2;

proc reg data = PCR_energy4 plots = all;
model log_Energy = datetime Press_mm_hg RH_1 RH_2 RH_3 RH_4 RH_5 RH_6 RH_7 RH_8 RH_9 RH_out
						T1 T2 T3 T4 T5 T6 T7 T8 T9 T_out Tdewpoint
						Visibility Windspeed rv1 rv2;
run;



*Blocked Cross-Validation to account for serial correlation-- default weekly lag of n = 7;

proc pls data=PCR_energy4 method=pcr cv = block plots = all;
model log_Energy = datetime Press_mm_hg RH_1 RH_2 RH_3 RH_4 RH_5 RH_6 RH_7 RH_8 RH_9 RH_out
						T1 T2 T3 T4 T5 T6 T7 T8 T9 T_out Tdewpoint
						Visibility Windspeed rv1 rv2
/*						
						RH_1*RH_2 RH_1*RH_3 RH_2*RH_3 RH_1*RH_6 RH_2*RH_6 RH_3*RH_7 RH_2*RH_8 
						RH_6*RH_out RH_4*T1 RH_6*T1 RH_1*T2 RH_2*T2 RH_4*T2	RH_6*T2	RH_8*T2	
						RH_out*T2 T1*T2 RH_3*T3 RH_4*T3 RH_6*T3 RH_1*T6 T3*T6 RH_2*T8 RH_3*T8
						RH_8*T8 T4*T8 RH_2*T9 RH_3*T9 RH_4*T9 RH_6*T9 RH_7*T9 T2*T9	T3*T9 T8*T9	
						RH_4*T_out RH_3*Windspeed T6*Windspeed T9*Windspeed
						
						RH_1*RH_2*RH_6 RH_2*RH_8*T2	RH_1*T1*T2 RH_3*T3*T4 RH_6*T2*T6 RH_out*T2*T6 
						RH_out*T6*T8 RH_1*RH_2*T9 RH_1*RH_6*T9 RH_2*RH_6*T9 RH_2*T2*T9 T3*T6*T9 
						RH_2*T8*T9 RH_8*T8*T9 T6*T8*T9 RH_out*T6*Windspeed T3*T6*Windspeed 
*/
;
run;


*Comparison with random forest output on most significant contributing individual variables;

proc hpforest data = PCR_energy4;
target log_Energy / level = interval;
input datetime Press_mm_hg RH_1 RH_2 RH_3 RH_4 RH_5 RH_6 RH_7 RH_8 RH_9 RH_out
						T1 T2 T3 T4 T5 T6 T7 T8 T9 T_out Tdewpoint
						Visibility Windspeed rv1 rv2 / level = interval;
run;
