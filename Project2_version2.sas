 /***************************************
Created 2 new variables in excel
->dayofweek - This will have week names Sunday to Saturday
-> HourofDay - THis has the truncated value of the hour from the timestamp


*************************************************/
 /***********Changing Data types*************/
            data WORK.ENERGY    ;
              infile '/home/athota0/Stats2/energydata_complete.csv' delimiter = ',' MISSOVER DSD  firstobs=2 ;
                 informat date $21. ;
                 informat Appliances  ;
                 informat lights  ;
                 informat T1  ;
                 informat RH_1  ;
                 informat T2  ;
                 informat RH_2  ;
                 informat T3  ;
                 informat RH_3  ;
                 informat T4 ;
                 informat RH_4  ;
                 informat T5  ;
                 informat RH_5  ;
                 informat T6 ;
                informat RH_6 ;
                informat T7 ;
                informat RH_7 ;
                informat T8 ;
                informat RH_8  ;
                informat T9  ;
                informat RH_9  ;
                informat T_out  ;
                informat Press_mm_hg  ;
                informat RH_out  ;
                informat Windspeed  ;
                informat Visibility  ;
                informat Tdewpoint  ;
                informat rv1  ;
                informat rv2  ;
                informat dayofweek $21.;
                informat HourofDay bestd20.19 ;
                
                format date $21. ;
                format Appliances  ;
                format lights bestd20.19  ;
                format T1 bestd20.19  ;
                format RH_1 bestd20.19  ;
                format T2 bestd20.19  ;
                format RH_2 bestd20.19  ;
                format T3 bestd20.19  ;
                format RH_3 bestd20.19  ;
                format T4 bestd20.19  ;
                format RH_4 bestd20.19  ;
                format T5 bestd20.19 ;
                format RH_5 bestd20.19  ;
                format T6 bestd20.19  ;
                format RH_6 bestd20.19  ;
                format T7 bestd20.19  ;
                format RH_7 bestd20.19  ;
                format T8 bestd20.19  ;
                format RH_8 bestd20.19  ;
                format T9 bestd20.19  ;
                format RH_9 bestd20.19  ;
                format T_out bestd20.19  ;
                format Press_mm_hg bestd20.19  ;
                format RH_out bestd20.19  ;
                format Windspeed bestd20.19  ;
                format Visibility bestd20.19  ;
                format Tdewpoint bestd20.19 ;
                format rv1 bestd20.19 ;
                format rv2 bestd15.14 ;
                format dayofweek $21.;
                format HourofDay bestd20.19 ;
             input
                         date $
                         Appliances 
                         lights 
                         T1 
                         RH_1 
                         T2 
                         RH_2 
                         T3 
                         RH_3 
                         T4 
                         RH_4 
                         T5 
                         RH_5 
                         T6 
                         RH_6 
                         T7 
                         RH_7 
                         T8 
                         RH_8 
                         T9 
                         RH_9 
                         T_out 
                         Press_mm_hg 
                         RH_out 
                         Windspeed 
                         Visibility 
                         Tdewpoint 
                         rv1 
                         rv2 
                         dayofweek $
                         HourofDay 
             ;
             /***Randonmly partitioning data into training and test data****/
             if ranuni(12345) < 0.7 then set="TRAINING";
             else set = "TESTING";
            run;
            
  data energy;
  set energy;
  Total_Energy_Consumption=Appliances+lights;
  run;
  /**************Splitting data into Train***************/           
  data Energy_train;
  set energy;
if set = "TESTING" then delete;
run;

/************Splitting data into Test*****************/
data Energy_test;
  set energy;
if set = "TRAINING" then delete;
run;

/**********Data analysis Scatterplot matrix**************/

proc sgscatter data=work.energy_train;
matrix Total_Energy_Consumption  T1  RH_1  T2  RH_2  T3  RH_3  T4   / ellipse diagonal=(histogram normal)  markerattrs =(color = orange) 
transparency=0.8;run;
proc sgscatter data=work.energy_train;
matrix 	Total_Energy_Consumption RH_4	T5	RH_5	T6	RH_6 T7	RH_7	T8	RH_8
 / ellipse diagonal=(histogram normal)  markerattrs =(color = orange) 
transparency=0.8;run;

proc sgscatter data=work.energy_train;
matrix 	Total_Energy_Consumption T9	RH_9	T_out	Press_mm_hg	RH_out	Windspeed	Visibility	Tdewpoint
 / ellipse diagonal=(histogram normal)  markerattrs =(color = orange) 
transparency=0.8;run;
/************Correlation heatmap***********************/
data corr_energy_train ;/*Creating a new Train dataset to pass to IML*/
   set energy_train(keep=Total_Energy_Consumption T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint dayofweek HourofDay);
   run;
proc corr data=work.corr_energy_train outp=corr(where=(_type_='CORR')) noprint;
run;

proc transpose data=corr(rename=(_name_=RowLab))
out=t(rename=(col1=Value _name_=ColLab));
by notsorted rowlab;
run;

data t2;
length v $ 5;
set t;
v = ifc(-1e-8 le value le 1e-8, ' 0',
ifc(rowlab eq collab, ' ---', put(value, 5.2)));
AbsValue = ifn(rowlab eq collab, 0, abs(value));
run;
ods graphics on / height=9in width=9in;
proc sgplot noautolegend;
title h=7pt 'Correlation Heatmap';
heatmapparm y=rowlab x=collab colorresponse=absvalue /
colormodel=(cxFAFBFE cx667FA2 cxD05B5B);
text y=rowlab x=collab text=v;
%let opts = display=(nolabel noticks) valueattrs=(size=7)
offsetmin=0.05 offsetmax=0.05;
xaxis &opts;
yaxis &opts reverse;
run;
title;

/********trying to create box plots*******
I want to understand how the variations in temperature are between different rooms********/
PROC SQL;
create table T_data as 
select * from 
(SELECT t1 as TVal, 'T1' as Name FROM energy_train
union
SELECT t2 as TVal, 'T2' as Name FROM energy_train
union
SELECT t3 as TVal, 'T3' as Name FROM energy_train
union
SELECT t4 as TVal, 'T4' as Name FROM energy_train
union
SELECT t5 as TVal, 'T5' as Name FROM energy_train
union
SELECT t7 as TVal, 'T7' as Name FROM energy_train
union
SELECT t8 as TVal, 'T8' as Name FROM energy_train
union
SELECT t9 as TVal, 'T9' as Name FROM energy_train) as T_data order by name;
QUIT;

proc sgplot data=T_data;
 vbox TVal / category=Name;
run;


/************************ Understand relationship between the Weekday/ Time of Day and Energy Consumption*******
I wasn't able to figureout how to create the below multivariable heap map in SAS. I did this in Tableau instead.
Below is the link for this:
https://public.tableau.com/profile/ashwin.thota#!/vizhome/Applianceenergyconsumption-Heapmap/Sheet1?publish=yes
****************************************/



/********* regression analysis*************/


data energy_train;
set energy_train;
log_Total_Energy_Consumption=log10(Total_Energy_Consumption);
run;

proc reg data = energy_train PLOTS(MAXPOINTS=NONE)= all;    
                                                 
model log_Total_Energy_Consumption = lights T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint / vif;                                                          
run;


proc glmselect data=energy_train_log PLOTS= all;
class dayofweek HourofDay;
model log_Total_Energy_Consumption =  T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint dayofweek HourofDay/selection=lasso(stop=cv) cvmethod=random(5) stats=adjrsq;
run;

proc glm data=energy_train plots(maxpoints=none)=all;
class HourofDay;
model log_Total_Energy_Consumption=
	
T2	
T3	
T6	
RH_8	
RH_out	
HourofDay;
run;



proc princomp plots=all data=energy_train out=pca;
      var T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint   ;
      run;
proc glm data=pca plots(maxpoints=none)=all;
class dayofweek HourofDay;
	model log_Total_Energy_Consumption= prin1-prin10 dayofweek HourofDay; 
	run;
	

/**********************PCA***************************************/

ods output Eigenvectors=Output ;        /* the data set name is 'Output' this should hold the Eigen vectors from Train*/
proc princomp data=energy_train out=pca1;
var T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint;
run;
 
proc print data=Output noobs/*noobs suppresses Obs numbers in the output*/;
run;

data energy_train_iml;/*Creating a new Train dataset to pass to IML*/
   set energy_train(keep=T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint);
   run;

/*********** Extracting PC's from Test Data************/
proc iml;
use Output;
read all var {Prin1	Prin2	Prin3	Prin4	Prin5 Prin6 Prin7 Prin8 Prin9 Prin10} into Test_Vector;/*Reasing first 5 significant PC's in to a matrix of 25x5*/
use energy_train_iml;
read all var {T1 RH_1 T2 RH_2 T3 RH_3 T4 RH_4 T5 RH_5 T6 RH_6 T7 RH_7 T8 RH_8 T9 RH_9 T_out Press_mm_hg RH_out Windspeed 
Visibility Tdewpoint} into energy_train_iml;/*NOTE: Should include the same # of variables as you have from the PCA analysis on TRAIN data*/
train_pca=(test_vector)`*(energy_train_iml)`; /*Multiply (5x25) with (25xN) to get 5xN*/
train_pca_T=(train_pca)`; /*Transpose 5xN to Nx5 N= number of obs in Train data and 5= # of significant PC's from Test */
/*print train_pca_T;*/
create Energy_Train_PCA from train_pca_T[colname={"PC1" "PC2" "PC3" "PC4" "PC5" "PC6" "PC7" "PC8" "PC9" "PC10"}];/* This will create a SAS data set from IML*/
append from train_pca_T;
close Energy_Train_PCA;
RUN;
proc print data=Energy_Train_PCA;run;

/********Running the Model on TEST Data*********/
data energy_test;
set energy_test;
log_Total_Energy_Consumption =log10(Total_Energy_Consumption);run;

data energy_test_subset;/*Creating a new Train dataset to pass to IML*/
   set energy_test(keep= log_Total_Energy_Consumption dayofweek HourofDay);
   run;
   
data combined;
    merge energy_test_subset Energy_Train_PCA;
run;

proc glm data=combined plots(maxpoints=none)=all;
class dayofweek HourofDay;
	model log_Total_Energy_Consumption= pc1-pc10 dayofweek HourofDay; 
	run;