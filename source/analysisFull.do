/* analysisFull v0.00            damiancclarke             yyyy-mm-dd:2018-07-23
----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8

This is the main analysis file for the results documented in the paper "Abortion
Reforms and Women's Health" by Damian Clarke and Hanna Mühlrad.  A working paper
version of this is available as IZA Discussion Paper 11890 (available at the fol
lowing address: http://ftp.iza.org/dp11890.pdf)

Required external ados are indicated in section 1 of the code.  The code can be
replicated by changing the globals in section 1 of the code. All data generating
code can be found in "generateFull.do". Raw data files are available from Damian
Clarke (damian.clarke@protonmail.com) or the INEGI website.  Only processed data
is currently on this repository, as the original data files are very large (> 20
GB).

*/

vers 12
clear all
set more off
cap log close

********************************************************************************
*** (1) Globals and locals
********************************************************************************
global DAT "~/investigacion/2018/ILE-health/data"
global OUT "~/investigacion/2018/ILE-health/results"
global LOG "~/investigacion/2018/ILE-health/log"

log using "$LOG/analysisFull.txt", text replace

local amorb abortionRelated extraction days_abortionRelated
local pub   deliveries haemorrhage O0* population 
local mort  maternalDeath abortiveDeaths

foreach ado in estout boottest synth ebalance {
    cap which `ado'
    if _rc!=0 ssc install `ado'
}	

********************************************************************************
*** (2) Basic plots and sum stats
********************************************************************************
use "$DAT/states/SeguroPopular", 
drop if year==2000
collapse T, by(statemx year)
rename statemx estado
rename T SP
drop if estado==.
tempfile SP
save `SP'

insheet using "$DAT/states/stateControls.csv", comma names clear
expand 2 if year==2015, gen(generated)
replace year = 2016 if generated==1
drop generated
foreach var of varlist homicides-gdppc {
    bys estado: ipolate `var' year, gen(`var'_i) epolate
    sum `var' `var'_i
    drop `var'
    rename `var'_i `var'
}
merge 1:1 estado year using `SP'
replace SP = 1 if _merge==1
drop _merge
tempfile controls
save `controls'

insheet using "$DAT/morbidity/macroTrends.csv", comma names clear
gen abortion    = smoclave==307|smoclave==308|smoclave==309
gen haemorrhage = smoclave==315
collapse (sum) smomuje, by(abortion haemorrhage anio entidad)
drop if abortion==0 & haemorrhage==0
gen haemorrhage_private = smomuje if haemorrhage==1
gen abortion_private    = smomuje if abortion==1

collapse (sum) haemorrhage_private abortion_private, by(anio entidad)
rename anio year
rename entidad estado
tempfile morbPriv
save `morbPriv'


use  "$DAT/Demographics_YearXState.dta"
merge 1:1 estado year using `controls'
drop _merge
merge 1:1 estado year using `morbPriv'
drop _merge

merge 1:1 estado year using "$DAT/mortality/mortalityYearState_wFamily.dta"


gen abortTotal = abortionRelated + abortion_private if abortionRelated!=.

lab var population      "Population of 15-49 Year-old Women"
lab var deliveries      "Total Number of Deliveries in Public Hospitals"
lab var totalONonBirth  "Total Inpatient Cases for ICD O codes, except births"
lab var abortionRelated "Total Inpatient Cases for Abortion-Related Causes"
lab var haemorrhage     "Total Inpatient Cases for Haemorrhage Early in Pregnancy"
lab var days_abortionRelated "Total Inpatient Days for Abortion-Related Causes"
lab var days_haemorrhag "Total Inpatient Days for Haemorrhage Early in Pregnancy"
lab var birth           "Total Number of Births"
lab var maternalDeath   "Total Number of Maternal Deaths"
lab var abortiveDeaths  "Total Number of Maternal Deaths due to Abortion"
lab var poverty      "Percent of State Living Below Poverty Line"
lab var accesshealth "Percent of State Residents with Access to Health Institutions"
lab var aveschool    "Average Schooling of Adult Population"
lab var womenactivee "Percent of Women of Working Age Economically Active"
lab var avesalary    "Average Salary of Full Time Workers"
lab var SP           "Proportion of Municipalities with Seguro Popular Coverage"

#delimit ;
local Nabort 87 40 19 11 28 19 34 31 104048 21 268 161 637 334 34703
          309 464 27 66 230 807 329 58 108 19 28 32 30 188 267 18 52; 
#delimit cr
tokenize `Nabort'
gen Nabort = .
foreach num of numlist 1(1)32 {
    replace Nabort = ``num'' if estado==`num'
}
gen pop815 = population if year>2007&year<2016

preserve
collapse Nabort (sum) pop815, by(stateName)
gen rate = Nabort/pop815*1000
rename stateName ADMIN_NAME
replace ADMIN_NAME="Distrito Federal"    if ADMIN_NAME=="DistritoFederal"
replace ADMIN_NAME="Baja California"     if ADMIN_NAME=="BajaCalifornia"
replace ADMIN_NAME="Baja California Sur" if ADMIN_NAME=="BajaCaliforniaSur"
replace ADMIN_NAME="Quintana Roo"        if ADMIN_NAME=="QuintanaRoo"
replace ADMIN_NAME="Nuevo Leon"          if ADMIN_NAME=="NuevoLeon"
replace ADMIN_NAME="San Luis Potosi"     if ADMIN_NAME=="SanLuisPotosi"
merge 1:1 ADMIN_NAME using "$DAT/geo/MexDB"

#delimit ;
spmap rate using "$DAT/geo/MexCoords", id(_ID)  osize(vvthin)
fcolor(Pastel1)
legend(title("Law Changes", size(*1.45) bexpand justification(left)))
legend(symy(*1.45) symx(*1.45) size(*1.98));
graph export "$OUT/Spillovers.eps", as(eps) replace;
#delimit cr
restore

bys estado: egen pop815c = sum(pop815)
gen AbortRate = Nabort/pop815c*1000



#delimit ;
estpost sum population deliveries totalONonBirth abortionRelated haemorrhage
days_abortionRelated days_haemorrhage birth maternalDeath abortiveDeaths;
estout using "$OUT/SummaryAll.tex", replace label style(tex)
cells("count mean(fmt(0)) sd(fmt(0)) min(fmt(0)) max(fmt(0))")
collabels(, none) mlabels(, none);
#delimit cr

gen birthRate = birth/population*1000
lab var birthRate "Birth rate per 1,000 women"
preserve
keep if year>=2001
#delimit ;
estpost sum population birth birthRate;
estout using "$OUT/SummaryDemog.tex", replace label style(tex)
cells("count mean(fmt(0)) sd(fmt(0)) min(fmt(0)) max(fmt(0))")
collabels(, none) mlabels(, none);

estpost sum deliveries totalONonBirth abortionRelated haemorrhage
days_abortionRelated days_haemorrhage;
estout using "$OUT/SummaryMorb.tex", replace label style(tex)
cells("count mean(fmt(0)) sd(fmt(0)) min(fmt(0)) max(fmt(0))")
collabels(, none) mlabels(, none);

estpost sum  maternalDeath abortiveDeaths;
estout using "$OUT/SummaryMort.tex", replace label style(tex)
cells("count mean(fmt(0)) sd(fmt(0)) min(fmt(0)) max(fmt(0))")
collabels(, none) mlabels(, none);

estpost sum  poverty accesshealth aveschool womenac avesalary SP;
estout using "$OUT/SummaryControls.tex", replace label style(tex)
cells("count mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))")
collabels(, none) mlabels(, none);
#delimit cr
restore



preserve
gen state = 1 if estado == 9
replace state=2 if regressiveState==1
replace state=0 if state==.
collapse (sum) `amorb' `pub' birth `mort', by(year state)


local l1 lwidth(medthick) lcolor(black) 
local l2 lwidth(medthick) lcolor(gs8) lpattern(dash)
local l3 lwidth(medium) lcolor(gs12) lpattern(longdash)  

keep if year<=2015
local j = 1
foreach var of varlist `amorb' `pub' birth `mort' {
    local folder morbidity
    local myear  2004
    if `j'==14 local folder fertility
    if `j'>=15 local folder mortality
    if `j'>=14 local myear 1990
    local ylab
    if `j'==1 local ylab ylabel(20000(5000)35000)
    #delimit ;
    twoway line `var' year if state==1&year>=`myear', yaxis(1) `l1'
    ||     line `var' year if state==0&year>=`myear', yaxis(2) `l2'
    ||     line `var' year if state==2&year>=`myear', yaxis(2) `l3'
    legend(label(1 "DF") label(2 "Other states") label(3 "Regressive"))
    xline(2007.33, lcolor(red)) xtitle("Year")  ytitle("Discharges DF")
    scheme(LF3) ytitle("Discharges other states", axis(2)) `ylab'; 
    graph export "$OUT/`folder'/allstates_`var'_total.eps", replace as(eps);
    #delimit cr

    gen `var'_del = `var'/deliveries*1000
    #delimit ;
    twoway line `var'_del year if state==1&year>=2004, `l1'
    ||     line `var'_del year if state==0&year>=2004, `l2'
    ||     line `var'_del year if state==2&year>=2004, `l3'
    legend(label(1 "DF") label(2 "Other states") label(3 "Regressive"))
    xline(2007.33, lcolor(red))
    xtitle("Year")  ytitle("Discharges per 1000 deliveries") scheme(LF3); 
    graph export "$OUT/`folder'/allstates_`var'_per_delivery.eps", replace as(eps);
    #delimit cr    

    gen `var'_pop = `var'/population*1000
    #delimit ;
    twoway line `var'_pop year if state==1&year>=`myear', `l1'
    ||     line `var'_pop year if state==0&year>=`myear', `l2'
    ||     line `var'_pop year if state==2&year>=`myear', `l3'
    legend(label(1 "DF") label(2 "Other states") label(3 "Regressive")
           size(medlarge))
    xline(2007.33, lcolor(red))
    xtitle("Year")  ytitle("Discharges per 1000 women") scheme(LF3); 
    graph export "$OUT/`folder'/allstates_`var'_per_population.eps", replace as(eps);
    #delimit cr    
    local ++j
}
restore


********************************************************************************
*** (3) synth yearly values
********************************************************************************
xtset estado year
local amorb abortionRelated abortTotal days_abortionRelated
local hmorb haemorrhage days_haemorrhage 


gen impact = .
local j = 1
foreach var in `amorb' `hmorb' birth maternalDeath abortiveDeaths familyViolence murderWoman murder {
    gen `var'Pop = `var'/population*1000
    gen `var'Del = `var'/deliveries*1000
    gen `var'Bir = `var'/birth*1000
    
    if `"`var'"' == "abortionRelated"      local name "Abortion Morbidity"
    if `"`var'"' == "abortTotal"           local name "Abortion Morbidity (Public and Private)"
    if `"`var'"' == "days_abortionRelated" local name "Abortion Morbidity (Inpatient Days)"
    if `"`var'"' == "haemorrhage"          local name "Haemorrhage Morbidity"
    if `"`var'"' == "days_haemorrhage"     local name "Haemorrhage (Inpatient Days)"
    if `"`var'"' == "infection"            local name "Infection Morbidity"
    if `"`var'"' == "extraction"           local name "Menstrual Extraction (ILE)"
    if `"`var'"' == "birth"                local name "Births"
    if `"`var'"' == "maternalDeath"        local name "Maternal Deaths"
    if `"`var'"' == "abortiveDeaths"       local name "Maternal Deaths due to Abortive Reasons"

    local folder morbidity
    if `j'==6 local folder fertility
    if `j'>=7 local folder mortality


    local ii = 1
    matrix DD = (-1,-1,-1,1,1,1,1,1,1,1,1,1)
    if `j'<6  local gvars `var' `var'Pop `var'Del 
    if `j'==6 local gvars `var' `var'Pop
    if `j'>6  local gvars `var' `var'Pop 


    foreach yvar in `gvars' {
        preserve
        if `j'<6  keep if year>=2004&year<=2015
        if `j'==6 keep if year>=2001&year<=2013
        if `j'>=7 keep if year>=2001
        if `j'<6  local xlab xlabel(2005(5)2015)
        if `j'>=6 local xlab xlabel(2001(2)2013)
        
        replace impact = .
        local rate "Rate"
        if `ii'==1 local rate  "Number of cases"
        if `ii'==1 local denom ""
        if `ii'==2 local denom "per 1,000 Women"
        if `ii'>=3 local denom "per 1,000 Births"
        
        #delimit ;
        local preds `yvar'(2006) `yvar'(2005) `yvar'(2004);
        if `j'>=6 local preds `yvar'(2006) `yvar'(2005) `yvar'(2004)
                              `yvar'(2003) `yvar'(2002) `yvar'(2001);

        synth `yvar' `preds', trunit(9) trperiod(2007) counit(1(1)8 10(1)14 16(1)32);
        matrix A = [e(Y_treated), e(Y_synthetic)];
        #delimit cr
        local averageTreat = 0
        foreach ts of numlist 5(1)12 {
            local treat`ts' = A[`ts',1]-A[`ts',2]
            local averageTreat = `averageTreat'+(`treat`ts'')/8
        }
        dis "Average Treatement Effect for `gvar' is `averageTreat'"

        local pre  = 3
	local post = 4
	local max  = 12
	if `j'>=6 local pre  = 6
        if `j'>=6 local post = 7
	if `j'>=6 local post = 15	
        *mat RMSPEpre = A[1..`pre',1]-A[1..`pre',2]
        *local RMSPEpre = 0
        *foreach n of numlist 1(1)`pre' {
        *    local RMSPEpre = `RMSPEpre'+ RMSPEpre[`n',1]^2
        *}
        *local RMSPEpre = sqrt(`RMSPEpre'/`pre')
        *mat RMSPEpost = A[`post'..`max',1]-A[`post'..`max',2]
        *local RMSPEpost = 0
        *foreach n of numlist 1(1)8 {
        *    local RMSPEpost = `RMSPEpost'+ RMSPEpost[`n',1]^2
        *}
        *local RMSPEpost = sqrt(`RMSPEpost'/8)
        *dis `RMSPEpre'
        *dis `RMSPEpost'
        *dis `RMSPEpost'/`RMSPEpre'

	
        matrix Imp = DD*(A[1..12,1]-A[1..12,2])/9
        local impact = Imp[1,1]
        replace impact = `impact' in 9
        
        #delimit ;
        svmat A, names(synth);
        if `j'< 6 gen yearS = 2003+_n in 1/12;
        if `j'>=6 gen yearS = 2000+_n in 1/15;
        twoway line synth1 yearS, lwidth(thick) ||
               line synth2 yearS, lwidth(thick) lpatter(dash) xline(2007)
        scheme(LF3) xtitle(Year) ytitle("`rate' of `name' `denom'") `xlab'
        legend(order(1 "Treatment (D.F.)" 2 "Synthetic Control") size(large));
        graph export "$OUT/`folder'/synth`yvar'.eps", replace;
        gen DifReal = synth1-synth2;
        drop synth1 synth2;
        #delimit cr
        local placebos
        local pNumerator   = 0
        local pDenominator = 0
        drop if estado==9
        local np = 1
        foreach num of numlist 1(1)8 10(1)14 15 16(1)32 {
            local lcol gs12
            if `num'==15|`num'==17|`num'==29|`num'==21|`num'==12|`num'==13 local lcol gs12
            #delimit ;
            dis "Round `num'";
            synth `yvar' `preds', trunit(`num') trperiod(2007);
            matrix A = [e(Y_treated), e(Y_synthetic)];
            matrix Imp = DD*(A[1..12,1]-A[1..12,2])/9;
            #delimit cr
            foreach ts of numlist 5(1)12 {
                local placebo`ts' = A[`ts',1]-A[`ts',2]
                if abs(`placebo`ts'')>abs(`treat`ts'') local ++pNumerator
                local ++pDenominator
            }
            matrix Dif = A[1..3,1]-A[1..3,2]
            mata: st_matrix("AbsDif",max(abs(st_matrix("Dif"))))
            local impact = Imp[1,1]
            local max = AbsDif[1,1]
            dis "max dif is `max'"
            if `max'<2|`ii'==1 {
                local ++np
                replace impact = `impact' in `num'
                svmat A, names(synth)
                gen Dif`num' = synth1-synth2
                drop synth1 synth2
                local placebos `placebos' line Dif`num' yearS, lcolor(`lcol') lpattern(dash) ||
            }
        }
        local pvalueS = `pNumerator'/`pDenominator'
        dis "p-value for `gvar' is `pvalueS'"
        dis "Impact is `averageTreat', p-value is `pvalueS'"
        #delimit ;
        twoway `placebos' line DifReal yearS, lwidth(thick) lcolor(black)
        legend(order(`np' "Mexico D.F." 2 "Placebo Permutations") size(medlarge))
        xline(2007) xtitle("Year") ytitle("`rate' of `name' `denom'") scheme(LF3) `xlab';
        graph export "$OUT/`folder'/synth`yvar'_Inference.eps", replace;
        #delimit cr
        drop yearS Dif*
        local ++ii
        sum impact
        sum impact in 9
        restore
    }                       
    local ++j
}


preserve
keep if year>=2004&year<=2015
cap gen haemorrhagePop = haemorrhage/population*1000
#delimit ;
synth haemorrhagePop haemorrhagePop(2004) haemorrhagePop(2005)
      haemorrhagePop(2006), trunit(9) trperiod(2007) counit(1(1)8 10(1)14 16(1)32);
#delimit cr  
matrix A = [e(Y_treated), e(Y_synthetic)]
mat MSPEpre = A[1..4,1]-A[1..4,2]
local MSPEpre = 0
foreach n of numlist 1(1)4 {
    local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
}
local MSPEpre = `MSPEpre'/4

mat MSPEpost = A[5..12,1]-A[5..12,2]
local MSPEpost = 0
foreach n of numlist 1(1)8 {
    local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
}
local MSPEpost = `MSPEpost'/8
dis `MSPEpre'
dis `MSPEpost'
dis `MSPEpost'/`MSPEpre'
gen MSPE = .
replace MSPE = `MSPEpost'/`MSPEpre' in 1

local jj=2
foreach num of numlist 1(1)8 10(1)14 16(1)32 {
    #delimit ;
    synth haemorrhagePop haemorrhagePop(2004) haemorrhagePop(2005)
          haemorrhagePop(2006), trunit(`num') trperiod(2007); 
    #delimit cr     
    matrix A = [e(Y_treated), e(Y_synthetic)]
    mat MSPEpre = A[1..4,1]-A[1..4,2]
    local MSPEpre = 0
    foreach n of numlist 1(1)4 {
        local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
    }
    local MSPEpre = `MSPEpre'/4
    
    mat MSPEpost = A[5..12,1]-A[5..12,2]
    local MSPEpost = 0
    foreach n of numlist 1(1)8 {
        local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
    }
    local MSPEpost = `MSPEpost'/8
    dis `MSPEpre'
    dis `MSPEpost'
    dis `MSPEpost'/`MSPEpre'
    replace MSPE = `MSPEpost'/`MSPEpre' in `jj'
    local ++jj
}                       
list MSPE in 1/32
restore



********************************************************************************
*** (4) synth yearly values, no regressive in control pool
********************************************************************************
foreach var of varlist haemorrhage abortionRelated {
    cap gen `var'Pop = `var'/population*1000
    preserve
    *drop if regressiveState==1
    xtset estado year
    keep if year>=2004&year<=2015
    gen Ests  = . 
    gen RMSPE = .
    
    local preds `var'Pop(2006) `var'Pop(2005) `var'Pop(2004)
    synth `var'Pop `preds', trunit(9) trperiod(2007)
    matrix A = [e(Y_treated), e(Y_synthetic)]
    mat alpha = J(1,8,1/8)*[A[5..12,1]-A[5..12,2]]
    mat MSPEpre = A[1..4,1]-A[1..4,2]
    local MSPEpre = 0
    foreach n of numlist 1(1)4 {
        local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
    }
    local MSPEpre = `MSPEpre'/4
    
    mat MSPEpost = A[5..12,1]-A[5..12,2]
    local MSPEpost = 0
    foreach n of numlist 1(1)8 {
        local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
    }
    local MSPEpost = `MSPEpost'/8
    dis `MSPEpre'
    dis `MSPEpost'
    dis `MSPEpost'/`MSPEpre'
    local MSPEreal = `MSPEpost'/`MSPEpre'

    gen MSPE = .
    local alphaO = alpha[1,1]
    
    local k = 1
    *foreach num of numlist 1 5 12 13 15 16 19 25 27 29 32 {
    foreach num of numlist 1 2 4(1)8 10(1)32 {
        dis "Round `num'"
	local preM  = 1
	local postM = 2
        foreach year of numlist 2005(1)2014 {
            local preds
            local yearM1 = `year'-1
            foreach yr of numlist 2005(1)`yearM1' {
                local preds `preds' `var'Pop(`yr')
            }
            synth `var'Pop `preds', trunit(`num') trperiod(`year')
            matrix A = [e(Y_treated), e(Y_synthetic)]
            matrix RMSPE = e(RMSPE)
            local post = 2015-`year'
            local pre  = `year'-2002
            mat alpha = J(1,`post',1/`post')*[A[`pre'..12,1]-A[`pre'..12,2]]
            local alpha = alpha[1,1]
            local RMSPE = RMSPE[1,1]
            dis "Alpha placebo is `alpha'.  Original Alpha is `alphaO'"
            replace Ests  = `alpha' in `k'
            replace RMSPE = `RMSPE' in `k'

            mat MSPEpre = A[1..`preM',1]-A[1..`preM',2]
            local MSPEpre = 0
            foreach n of numlist 1(1)`preM' {
                local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
            }
            local MSPEpre = `MSPEpre'/`preM'

            local npost = 12-`postM' 
            mat MSPEpost = A[`postM'..12,1]-A[`postM'..12,2]
            local MSPEpost = 0
            foreach n of numlist 1(1)`npost' {
                local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
            }
            local MSPEpost = `MSPEpost'/`npost'
            replace MSPE = `MSPEpost'/`MSPEpre' in `k'
            local ++k
	    local ++preM
	    local ++postM
        }
    }
    hist MSPE, xline(`MSPEreal') scheme(LF3) xtitle("Pre/Post-MSPE Prediction Error")
    graph export "$OUT/MSPE_`var'.eps", replace
    count if abs(Ests)>abs(`alphaO') & Ests!=.
    local N = r(N)
    local tspv = string(`N'/(`k'-1), "%05.3f")

    if `"`var'"'=="haemorrhage" local lim = 0.4 
    if `"`var'"'=="abortionRelated" local lim = 2
    count if abs(Ests)>abs(`alphaO') & Ests!=.&RMSPE<`lim'
    local N = r(N)
    count if RMSPE>=`lim'&RMSPE!=.
    local Nd = r(N)
    local tspvT = string(`N'/(`k'-`Nd'-1), "%05.3f")
    
    count if Ests<`alphaO' 
    local N = r(N)
    local ospv = string(`N'/(`k'-1), "%05.3f")

    count if Ests<`alphaO' &RMSPE < `lim'
    local N = r(N)
    count if RMSPE>=`lim'&RMSPE!=.
    local Nd = r(N)
    local ospvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

    #delimit ;
    hist Ests, xline(`alphaO') scheme(LF3) bin(20) xtitle("Null Distribution")
    note("Two sided p-value: `tspv'. RMSPE-trimmed Two sided p-value: `tspvT'."
         "One sided p-value: `ospv'. RMSPE-trimmed One sided p-value: `ospvT'.");
    #delimit cr
    graph export "$OUT/randomisationInference_`var'.eps", replace
    sum RMSPE
    hist RMSPE, xline(`alphaO') scheme(LF3) bin(20) xtitle("Root Mean Squared Prediction Error")
    graph export "$OUT/RMSPE_RI_`var'.eps", replace
    replace Ests = abs(Ests)
    count if Ests>abs(`alphaO') & Ests!=.
    local pv = r(N)/(`k'-1)
    dis `alphaO'
    dis `pv'
    
    restore
}


cap gen birthPop = birth/population*1000
preserve
xtset estado year
keep if year>=2001&year<=2013
gen Ests  = . 
gen RMSPE = .
    
local preds         birthPop(2006) birthPop(2005) birthPop(2004)
local preds `preds' birthPop(2003) birthPop(2002) birthPop(2001)
synth birthPop `preds', trunit(9) trperiod(2007)
matrix A = [e(Y_treated), e(Y_synthetic)]
mat alpha = J(1,7,1/7)*[A[7..13,1]-A[7..13,2]]
mat MSPEpre = A[1..6,1]-A[1..6,2]
local MSPEpre = 0
foreach n of numlist 1(1)6 {
    local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
}
local MSPEpre = `MSPEpre'/6
    
mat MSPEpost = A[7..13,1]-A[7..13,2]
local MSPEpost = 0
foreach n of numlist 1(1)7 {
    local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
}
local MSPEpost = `MSPEpost'/7
dis `MSPEpre'
dis `MSPEpost'
dis `MSPEpost'/`MSPEpre'
local MSPEreal = `MSPEpost'/`MSPEpre'

gen MSPE = .
local alphaO = alpha[1,1]
    
local k = 1
foreach num of numlist 1 2 4(1)8 10(1)32 {
    dis "Round `num'"
    local preM  = 1
    local postM = 2
    foreach year of numlist 2002(1)2012 {
        local preds
        local yearM1 = `year'-1
        foreach yr of numlist 2001(1)`yearM1' {
            local preds `preds' birthPop(`yr')
        }
        synth birthPop `preds', trunit(`num') trperiod(`year')
        matrix A = [e(Y_treated), e(Y_synthetic)]
        matrix RMSPE = e(RMSPE)
        local post = 2013-`year'
        local pre  = `year'-1999
        ***NOTE: This gives pre as 3 in 1st iteration.  Makes alpha go from 3 onwards
        mat alpha = J(1,`post',1/`post')*[A[`pre'..13,1]-A[`pre'..13,2]]
        local alpha = alpha[1,1]
        local RMSPE = RMSPE[1,1]
	dis "Test"
        dis "Alpha placebo is `alpha'.  Original Alpha is `alphaO'"
        replace Ests  = `alpha' in `k'
        replace RMSPE = `RMSPE' in `k'

        mat MSPEpre = A[1..`preM',1]-A[1..`preM',2]
        local MSPEpre = 0
        foreach n of numlist 1(1)`preM' {
            local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
        }
        local MSPEpre = `MSPEpre'/`preM'

        local npost = 13-`postM' 
        mat MSPEpost = A[`postM'..13,1]-A[`postM'..13,2]
        local MSPEpost = 0
        foreach n of numlist 1(1)`npost' {
            local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
        }
        local MSPEpost = `MSPEpost'/`npost'
        replace MSPE = `MSPEpost'/`MSPEpre' in `k'
        local ++k
	local ++preM
	local ++postM
    }
}
sum MSPE, d
#delimit ;
hist MSPE if MSPE<1000, xline(`MSPEreal') scheme(LF3)
xtitle("Pre/Post-MSPE Prediction Error");
#delimit cr
graph export "$OUT/MSPE_birth.eps", replace
count if abs(Ests)>abs(`alphaO') & Ests!=.
local N = r(N)
local tspv = string(`N'/(`k'-1), "%05.3f")

local lim=5
count if abs(Ests)>abs(`alphaO') & Ests!=.&RMSPE<`lim'
local N = r(N)
count if RMSPE>=`lim'&RMSPE!=.
local Nd = r(N)
local tspvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

count if Ests<`alphaO' 
local N = r(N)
local ospv = string(`N'/(`k'-1), "%05.3f")

count if Ests<`alphaO' &RMSPE < `lim'
local N = r(N)
count if RMSPE>=`lim'&RMSPE!=.
local Nd = r(N)
local ospvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

#delimit ;
hist Ests, xline(`alphaO') scheme(LF3) bin(20) xtitle("Null Distribution")
note("Two sided p-value: `tspv'. RMSPE-trimmed Two sided p-value: `tspvT'."
     "One sided p-value: `ospv'. RMSPE-trimmed One sided p-value: `ospvT'.");
#delimit cr
graph export "$OUT/randomisationInference_birth.eps", replace
sum RMSPE
hist RMSPE, xline(`alphaO') scheme(LF3) bin(20) xtitle("Root Mean Squared Prediction Error")
graph export "$OUT/RMSPE_RI_birth.eps", replace
replace Ests = abs(Ests)
count if Ests>abs(`alphaO') & Ests!=.
local pv = r(N)/(`k'-1)
dis `alphaO'
dis `pv'

restore



local j = 1
foreach var in `amorb' `hmorb' birth maternalDeath abortiveDeaths {
    cap gen `var'Pop = `var'/population*1000
    cap gen `var'Del = `var'/deliveries*1000
    cap gen `var'Bir = `var'/birth*1000
    
    if `"`var'"' == "abortionRelated"      local name "Abortion Morbidity"
    if `"`var'"' == "days_abortionRelated" local name "Abortion Morbidity (Inpatient Days)"
    if `"`var'"' == "haemorrhage"          local name "Haemorrhage Morbidity"
    if `"`var'"' == "days_haemorrhage"     local name "Haemorrhage (Inpatient Days)"
    if `"`var'"' == "extraction"           local name "Menstrual Extraction (ILE)"
    if `"`var'"' == "birth"                local name "Births"
    if `"`var'"' == "maternalDeath"        local name "Maternal Deaths"
    if `"`var'"' == "abortiveDeaths"       local name "Maternal Deaths due to Abortive Reasons"

    local folder morbidity
    if `j'==6 local folder fertility
    if `j'>=7 local folder mortality


    local ii = 1
    if `j'<6  local gvars `var' `var'Pop `var'Del 
    if `j'==6 local gvars `var' `var'Pop
    if `j'>6  local gvars `var' `var'Pop 
    
    foreach yvar in `gvars' {
        preserve
        drop if regressiveState==1
        xtset estado year
        if `j'<6  keep if year>=2004&year<=2015
        if `j'==6 keep if year>=2001&year<=2013
        if `j'>=7 keep if year>=2001

        local rate "Rate"
        if `ii'==1 local rate  "Number of cases"
        if `ii'==1 local denom ""
        if `ii'==2 local denom "per 1,000 Women"
        if `ii'==3 local denom "per 1,000 Births"
        
        #delimit ;
        local preds `yvar'(2006) `yvar'(2005) `yvar'(2004);
        if `j'>=6 local preds `yvar'(2006) `yvar'(2005) `yvar'(2004)
                              `yvar'(2003) `yvar'(2002) `yvar'(2001);

        synth `yvar' `preds', trunit(9) trperiod(2007);
        matrix A = [e(Y_treated), e(Y_synthetic)];        
        svmat A, names(synth);
        if `j'< 6 gen yearS = 2003+_n in 1/12;
        if `j'>=6 gen yearS = 2000+_n in 1/15;
        twoway line synth1 yearS, lwidth(thick) ||
               line synth2 yearS, lwidth(thick) lpatter(dash) xline(2007)
        scheme(LF3) xtitle(Year) ytitle("`rate' of `name' `denom'")
        legend(order(1 "Treatment (D.F.)" 2 "Synthetic Control") size(large));
        graph export "$OUT/`folder'/synth`yvar'_noRegressive.eps", replace;
        gen DifReal = synth1-synth2;
        drop synth1 synth2;
        #delimit cr
        local placebos
        foreach num of numlist 1 3 5 12 13 15 16 19 25 27 29 32 {
            #delimit ;
            dis "Round `num'";
            synth `yvar' `preds', trunit(`num') trperiod(2007);
            matrix A = [e(Y_treated), e(Y_synthetic)];
            svmat A, names(synth);
            gen Dif`num' = synth1-synth2;
            drop synth1 synth2;
            local placebos `placebos' line Dif`num' yearS, lcolor(gs12) lpattern(dash) ||;
            #delimit cr
        }
        #delimit ;
        twoway `placebos' line DifReal yearS, lwidth(thick) scheme(LF3)
        legend(order(32 "Mexico D.F." 2 "Placebo Permutations") size(medlarge))
        xline(2007) xtitle("");
        graph export "$OUT/`folder'/synth`yvar'_Inference_noRegressive.eps", replace;
        #delimit cr
        drop yearS Dif*
        local ++ii
        restore
    }                       
    local ++j
}



********************************************************************************
*** (5) Spillovers
********************************************************************************
xtset estado year
replace birth=birth*1.1 if estado==15
foreach state in 13 15 17 {
    if `state'==13 local csname "Hidalgo"
    if `state'==15 local csname "Mexico State"
    if `state'==17 local csname "Morelos"
    
    local j = 1
    foreach var in abortionRelated haemorrhage birth maternalDeath abortiveDeaths {
        cap drop `var'Pop
        gen `var'Pop = `var'/population*1000
           
        if `"`var'"' == "birth"                local name "Births"
        if `"`var'"' == "abortionRelated"      local name "Abortion Morbidity"
        if `"`var'"' == "haemorrhage"          local name "Haemorrhage Morbidity"
        if `"`var'"' == "maternalDeath"        local name "Maternal Deaths"
        if `"`var'"' == "abortiveDeaths"       local name "Maternal Deaths due to Abortive Reasons"
    
        local folder morbidity
        if `j'==3 local folder fertility
        if `j'>=4 local folder mortality
        
        preserve
        if `j'<3  keep if year>=2004&year<=2015
        if `j'==3 keep if year>=2001&year<=2013
        if `j'>=4 keep if year>=2001
        if `j'<3  local xlab xlabel(2005(5)2015)
        if `j'>=3 local xlab xlabel(2001(2)2013)
    
        local yvar `var'Pop
        #delimit ;
        local preds `yvar'(2006) `yvar'(2005) `yvar'(2004);
        if `j'>=3 local preds `yvar'(2006) `yvar'(2005) `yvar'(2004)
                               `yvar'(2003) `yvar'(2002) `yvar'(2001);
    
        synth `yvar' `preds', trunit(`state') trperiod(2007);
        matrix A = [e(Y_treated), e(Y_synthetic)];
            
        svmat A, names(synth);
        if `j'< 3 gen yearS = 2003+_n in 1/12;
        if `j'>=3 gen yearS = 2000+_n in 1/15;
        twoway line synth1 yearS, lwidth(thick) ||
               line synth2 yearS, lwidth(thick) lpatter(dash) xline(2007)
        scheme(LF3) xtitle(Year) ytitle("Rate of `name' per 1000 Births") `xlab'
        legend(order(1 "Treatment (D.F.)" 2 "Synthetic Control") size(large));
        graph export "$OUT/`folder'/CLOSE`state'_synth`yvar'.eps", replace;
        gen DifReal = synth1-synth2;
        drop synth1 synth2;
        #delimit cr
        local placebos
        foreach num of numlist 1(1)8 10(1)12 14 16 18(1)32 {
            local lcol gs12
            #delimit ;
            dis "Round `num'";
            synth `yvar' `preds', trunit(`num') trperiod(2007);
            matrix A = [e(Y_treated), e(Y_synthetic)];
            #delimit cr
            svmat A, names(synthB)
            gen Dif`num' = synthB1-synthB2
            drop synthB1 synthB2
            local placebos `placebos' line Dif`num' yearS, lcolor(`lcol') lpattern(dash) ||
        }
        #delimit ;
        twoway `placebos' line DifReal yearS, lwidth(thick) lcolor(black)
        legend(order(29 "`csname'" 2 "Placebo Permutations") size(medlarge))
        xline(2007) xtitle("Year") scheme(LF3) `xlab';
        graph export "$OUT/`folder'/CLOSE`state'_synth`yvar'_Inference.eps", replace;
        #delimit cr
        restore
        local ++j
    }
    exit




foreach var of varlist haemorrhage abortionRelated {
    cap gen `var'Pop = `var'/population*1000
    preserve
    xtset estado year
    keep if year>=2004&year<=2015
    gen Ests  = . 
    gen RMSPE = .
    
    local preds `var'Pop(2006) `var'Pop(2005) `var'Pop(2004)
    synth `var'Pop `preds', trunit(`state') trperiod(2007)
    matrix A = [e(Y_treated), e(Y_synthetic)]
    mat alpha = J(1,8,1/8)*[A[5..12,1]-A[5..12,2]]
    mat MSPEpre = A[1..4,1]-A[1..4,2]
    local MSPEpre = 0
    foreach n of numlist 1(1)4 {
        local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
    }
    local MSPEpre = `MSPEpre'/4
    
    mat MSPEpost = A[5..12,1]-A[5..12,2]
    local MSPEpost = 0
    foreach n of numlist 1(1)8 {
        local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
    }
    local MSPEpost = `MSPEpost'/8
    dis `MSPEpre'
    dis `MSPEpost'
    dis `MSPEpost'/`MSPEpre'
    local MSPEreal = `MSPEpost'/`MSPEpre'

    gen MSPE = .
    local alphaO = alpha[1,1]
    
    local k = 1
    foreach num of numlist 1 2 4(1)8 10(1)12 14 16 18(1)32 {
        dis "Round `num'"
	local preM  = 1
	local postM = 2
        foreach year of numlist 2005(1)2014 {
            local preds
            local yearM1 = `year'-1
            foreach yr of numlist 2005(1)`yearM1' {
                local preds `preds' `var'Pop(`yr')
            }
            synth `var'Pop `preds', trunit(`num') trperiod(`year')
            matrix A = [e(Y_treated), e(Y_synthetic)]
            matrix RMSPE = e(RMSPE)
            local post = 2015-`year'
            local pre  = `year'-2002
            mat alpha = J(1,`post',1/`post')*[A[`pre'..12,1]-A[`pre'..12,2]]
            local alpha = alpha[1,1]
            local RMSPE = RMSPE[1,1]
            dis "Alpha placebo is `alpha'.  Original Alpha is `alphaO'"
            replace Ests  = `alpha' in `k'
            replace RMSPE = `RMSPE' in `k'

            mat MSPEpre = A[1..`preM',1]-A[1..`preM',2]
            local MSPEpre = 0
            foreach n of numlist 1(1)`preM' {
                local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
            }
            local MSPEpre = `MSPEpre'/`preM'

            local npost = 12-`postM' 
            mat MSPEpost = A[`postM'..12,1]-A[`postM'..12,2]
            local MSPEpost = 0
            foreach n of numlist 1(1)`npost' {
                local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
            }
            local MSPEpost = `MSPEpost'/`npost'
            replace MSPE = `MSPEpost'/`MSPEpre' in `k'
            local ++k
	    local ++preM
	    local ++postM
        }
    }
    *hist MSPE, xline(`MSPEreal') scheme(LF3) xtitle("Pre/Post-MSPE Prediction Error")
    *graph export "$OUT/MSPE_`var'.eps", replace
    count if abs(Ests)>abs(`alphaO') & Ests!=.
    local N = r(N)
    local tspv = string(`N'/(`k'-1), "%05.3f")

    if `"`var'"'=="haemorrhage" local lim = 0.4 
    if `"`var'"'=="abortionRelated" local lim = 2
    count if abs(Ests)>abs(`alphaO') & Ests!=.&RMSPE<`lim'
    local N = r(N)
    count if RMSPE>=`lim'&RMSPE!=.
    local Nd = r(N)
    local tspvT = string(`N'/(`k'-`Nd'-1), "%05.3f")
    
    count if Ests<`alphaO' 
    local N = r(N)
    local ospv = string(`N'/(`k'-1), "%05.3f")

    count if Ests<`alphaO' &RMSPE < `lim'
    local N = r(N)
    count if RMSPE>=`lim'&RMSPE!=.
    local Nd = r(N)
    local ospvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

    #delimit ;
    hist Ests, xline(`alphaO') scheme(LF3) bin(20) xtitle("Null Distribution")
    note("Two sided p-value: `tspv'. RMSPE-trimmed Two sided p-value: `tspvT'."
         "One sided p-value: `ospv'. RMSPE-trimmed One sided p-value: `ospvT'.");
    #delimit cr
    graph export "$OUT/CLOSE`state'randomisationInference_`var'.eps", replace
    sum RMSPE
    replace Ests = abs(Ests)
    count if Ests>abs(`alphaO') & Ests!=.
    local pv = r(N)/(`k'-1)
    dis `alphaO'
    dis `pv'    
    restore
}


cap gen birthPop = birth/population*1000
preserve
xtset estado year
keep if year>=2001&year<=2013
gen Ests  = . 
gen RMSPE = .
    
local preds         birthPop(2006) birthPop(2005) birthPop(2004)
local preds `preds' birthPop(2003) birthPop(2002) birthPop(2001)
synth birthPop `preds', trunit(`state') trperiod(2007)
matrix A = [e(Y_treated), e(Y_synthetic)]
mat alpha = J(1,7,1/7)*[A[7..13,1]-A[7..13,2]]
mat MSPEpre = A[1..6,1]-A[1..6,2]
local MSPEpre = 0
foreach n of numlist 1(1)6 {
    local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
}
local MSPEpre = `MSPEpre'/6
    
mat MSPEpost = A[7..13,1]-A[7..13,2]
local MSPEpost = 0
foreach n of numlist 1(1)7 {
    local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
}
local MSPEpost = `MSPEpost'/7
dis `MSPEpre'
dis `MSPEpost'
dis `MSPEpost'/`MSPEpre'
local MSPEreal = `MSPEpost'/`MSPEpre'

gen MSPE = .
local alphaO = alpha[1,1]
    
local k = 1
foreach num of numlist 1 2 4(1)8 10(1)12 14 16 18(1)32 {
    dis "Round `num'"
    local preM  = 1
    local postM = 2
    foreach year of numlist 2002(1)2012 {
        local preds
        local yearM1 = `year'-1
        foreach yr of numlist 2001(1)`yearM1' {
            local preds `preds' birthPop(`yr')
        }
        synth birthPop `preds', trunit(`num') trperiod(`year')
        matrix A = [e(Y_treated), e(Y_synthetic)]
        matrix RMSPE = e(RMSPE)
        local post = 2013-`year'
        local pre  = `year'-1999
        ***NOTE: This gives pre as 3 in 1st iteration.  Makes alpha go from 3 onwards
        mat alpha = J(1,`post',1/`post')*[A[`pre'..13,1]-A[`pre'..13,2]]
        local alpha = alpha[1,1]
        local RMSPE = RMSPE[1,1]
	dis "Test"
        dis "Alpha placebo is `alpha'.  Original Alpha is `alphaO'"
        replace Ests  = `alpha' in `k'
        replace RMSPE = `RMSPE' in `k'

        mat MSPEpre = A[1..`preM',1]-A[1..`preM',2]
        local MSPEpre = 0
        foreach n of numlist 1(1)`preM' {
            local MSPEpre = `MSPEpre'+ MSPEpre[`n',1]^2
        }
        local MSPEpre = `MSPEpre'/`preM'

        local npost = 13-`postM' 
        mat MSPEpost = A[`postM'..13,1]-A[`postM'..13,2]
        local MSPEpost = 0
        foreach n of numlist 1(1)`npost' {
            local MSPEpost = `MSPEpost'+ MSPEpost[`n',1]^2
        }
        local MSPEpost = `MSPEpost'/`npost'
        replace MSPE = `MSPEpost'/`MSPEpre' in `k'
        local ++k
	local ++preM
	local ++postM
    }
}
sum MSPE, d
#delimit ;
hist MSPE if MSPE<1000, xline(`MSPEreal') scheme(LF3)
xtitle("Pre/Post-MSPE Prediction Error");
#delimit cr
graph export "$OUT/MSPE_birth.eps", replace
count if abs(Ests)>abs(`alphaO') & Ests!=.
local N = r(N)
local tspv = string(`N'/(`k'-1), "%05.3f")

local lim=5
count if abs(Ests)>abs(`alphaO') & Ests!=.&RMSPE<`lim'
local N = r(N)
count if RMSPE>=`lim'&RMSPE!=.
local Nd = r(N)
local tspvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

count if Ests<`alphaO' 
local N = r(N)
local ospv = string(`N'/(`k'-1), "%05.3f")

count if Ests<`alphaO' &RMSPE < `lim'
local N = r(N)
count if RMSPE>=`lim'&RMSPE!=.
local Nd = r(N)
local ospvT = string(`N'/(`k'-`Nd'-1), "%05.3f")

#delimit ;
hist Ests, xline(`alphaO') scheme(LF3) bin(20) xtitle("Null Distribution")
note("Two sided p-value: `tspv'. RMSPE-trimmed Two sided p-value: `tspvT'."
     "One sided p-value: `ospv'. RMSPE-trimmed One sided p-value: `ospvT'.");
#delimit cr
graph export "$OUT/CLOSE`state'randomisationInference_birth.eps", replace
sum RMSPE
replace Ests = abs(Ests)
count if Ests>abs(`alphaO') & Ests!=.
local pv = r(N)/(`k'-1)
dis `alphaO'
dis `pv'

restore
}


********************************************************************************
*** (6) Difference-in-differences
********************************************************************************
gen ReformClose = estado==15&year>=2007
gen post7 = year>=2007

local pwt        [aw=population]
local Treat      ILE regressive
local FE         i.year i.estado ReformClose 
local trend      i.estado#c.year
local X          poverty accesshealth aveschool womenac avesalary SP 
local se         cluster(estado)

gen ILEcont = AbortRate
replace ILEcont = 0 if year<2007
preserve
keep if year>=2001
foreach var of varlist birth abortionRelated haemorrhage maternalDeath abortiveDeaths {
    cap drop `var'Pop
    gen `var'Pop = `var'/population*1000
    regress `var'Pop ILEcont regressive `X' i.year i.estado `pwt', cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILEcont=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    sum `var'Pop
    local N    = r(N)
    local mean = r(mean)
    sum `var'Pop if estado==9&year<2007
    local Pmean = r(mean)
    sum `var'Pop if regressiveState==1&regressive==0
    local Rmean = r(mean)
    estadd scalar mean  = `mean'
    estadd scalar pmean = `Pmean'
    estadd scalar rmean = `Rmean'
    estadd scalar N     = `N'
}
lab var regressive "Post-Regressive Law Change"
lab var ILEcont "Abortions per 1,000 Women"
#delimit ;
esttab est1 est2 est3 est4 est5 using "$OUT/DD_intensity.tex",
b(%-9.3f) se(%-9.3f) noobs keep(ILEcont regressive) nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
stats(N mean, fmt(%9.0gc %5.3f)
      label("\\ Observations" "Mean of Dependent Variable"));
#delimit cr
estimates clear


*-------------------------------------------------------------------------------
*--(A) Morbidity
*-------------------------------------------------------------------------------
gen treat = estado == 9
foreach var in abortionRelated haemorrhage days_abortionRelated days_haemorrhage {
    matrix bse = J(2,1,.)
    cap drop `var'Pop
    gen `var'Pop = `var'/population*1000
    regress `var'Pop `Treat' `FE', cluster(estado)
    sum `var'Pop
    local mean = r(mean)
    local N    = e(N)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'
    
    regress `var'Pop `Treat' `FE' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'
    
    regress `var'Pop `Treat' `FE' `X', cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Pop `Treat' `FE' `X' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'    
}
lab var regressive "Post-Regressive Law Change"
lab var ILE        "Post-ILE Reform (DF)"

#delimit ;
esttab est1 est2 est3 est4 est5 est6 est7 est8 using "$OUT/DD_morbidity.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));

esttab est9 est10 est11 est12 est13 est14 est15 est16 using "$OUT/DD_morbidity_days.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));
#delimit cr
estimates clear


foreach var in abortionRelated haemorrhage days_abortionRelated days_haemorrhage {
    cap drop `var'Bir
    gen `var'Bir = `var'/birth*1000
    regress `var'Bir `Treat' `FE', cluster(estado)
    sum `var'Bir
    local mean = r(mean)
    local N    = e(N)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `FE' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `X' `FE', cluster(estado)
    sum `var'Bir
    local mean = r(mean)
    local N    = e(N)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `X' `FE' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'
}
lab var regressive "Post-Regressive Law Change"
lab var ILE        "Post-ILE Reform (DF)"

#delimit ;
esttab est1 est2 est3 est4 est5 est6 est7 est8 using "$OUT/DD_morbidity_birth_trend.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));

esttab est9 est10 est11 est12 est13 est14 est15 est16 using "$OUT/DD_morbidity_birth_days_trend.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));
#delimit cr
estimates clear
drop treat

*-------------------------------------------------------------------------------
*--(B) Mortality
*-------------------------------------------------------------------------------
foreach var in maternalDeath abortiveDeaths {
    preserve
    keep if year>=2001
    gen treat = estado == 9
    cap drop `var'Pop
    gen `var'Pop = `var'/population*100000
    regress `var'Pop `Treat' `FE'                 , cluster(estado)
    sum `var'Pop
    local mean = r(mean)
    local N    = e(N)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Pop `Treat' `FE' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Pop `Treat' `FE' `X'               , cluster(estado)
    sum `var'Pop
    local mean = r(mean)
    local N    = e(N)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Pop `Treat' `FE' `X' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    drop if year>2013
    cap drop `var'Bir
    
    gen `var'Bir = `var'/birth*100000
    regress `var'Bir `Treat' `FE'                , cluster(estado)
    sum `var'Bir
    local mean = r(mean)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `FE' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `FE' `X'               , cluster(estado)
    sum `var'Bir
    local mean = r(mean)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'

    regress `var'Bir `Treat' `FE' `X' [aw=population], cluster(estado)
    matrix v = e(V)
    matrix b = e(b)
    boottest ILE=0, boottype(wild) seed(22)
    matrix v[1,1] = (_b[ILE]/r(t))^2
    boottest regressive=0, boottype(wild) seed(22)
    matrix v[2,2] = (_b[regressive]/r(t))^2
    eststo: ereturn post b v
    estadd scalar mean = `mean'
    estadd scalar N    = `N'
    
    restore
}
lab var regressive "Post Regressive Law Change"
lab var ILE        "Post-ILE Reform (DF)"

#delimit ;
esttab est1 est2 est3 est4 est9 est10 est11 est12 using "$OUT/DD_mortality.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));

esttab est5 est6 est7 est8 est13 est14 est15 est16 using "$OUT/DD_mortality_Birth.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));
#delimit cr
estimates clear


*-------------------------------------------------------------------------------
*--(C) Fertility
*-------------------------------------------------------------------------------
preserve
keep if year>=2001&year<2014
gen treat = estado == 9
cap drop fertPop
gen fertPop = birth/population*1000
regress fertPop `Treat' `FE', cluster(estado)
matrix v = e(V)
matrix b = e(b)
boottest ILE=0, boottype(wild) seed(22)
matrix v[1,1] = (_b[ILE]/r(t))^2
boottest regressive=0, boottype(wild) seed(22)
matrix v[2,2] = (_b[regressive]/r(t))^2
eststo: ereturn post b v
sum fertPop
local N    = r(N)
local mean = r(mean)
sum fertPop if estado==9&year<2007
local Pmean = r(mean)
sum fertPop if regressiveState==1&regressive==0
local Rmean = r(mean)
estadd scalar mean  = `mean'
estadd scalar pmean = `Pmean'
estadd scalar rmean = `Rmean'
estadd scalar N     = `N'

regress fertPop `Treat' `FE' [aw=population], cluster(estado)
matrix v = e(V)
matrix b = e(b)
boottest ILE=0, boottype(wild) seed(22)
matrix v[1,1] = (_b[ILE]/r(t))^2
boottest regressive=0, boottype(wild) seed(22)
matrix v[2,2] = (_b[regressive]/r(t))^2
eststo: ereturn post b v
estadd scalar mean  = `mean'
estadd scalar pmean = `Pmean'
estadd scalar rmean = `Rmean'
estadd scalar N     = `N'

regress fertPop `Treat' `X' `FE', cluster(estado)
matrix v = e(V)
matrix b = e(b)
boottest ILE=0, boottype(wild) seed(22)
matrix v[1,1] = (_b[ILE]/r(t))^2
boottest regressive=0, boottype(wild) seed(22)
matrix v[2,2] = (_b[regressive]/r(t))^2
eststo: ereturn post b v
estadd scalar mean  = `mean'
estadd scalar pmean = `Pmean'
estadd scalar rmean = `Rmean'
estadd scalar N     = `N'


regress fertPop `Treat' `X' `FE' [aw=population], cluster(estado)
matrix v = e(V)
matrix b = e(b)
boottest ILE=0, boottype(wild) seed(22)
matrix v[1,1] = (_b[ILE]/r(t))^2
boottest regressive=0, boottype(wild) seed(22)
matrix v[2,2] = (_b[regressive]/r(t))^2
eststo: ereturn post b v
estadd scalar mean  = `mean'
estadd scalar pmean = `Pmean'
estadd scalar rmean = `Rmean'
estadd scalar N     = `N'

lab var ILE        "Post-ILE Reform (DF)"

#delimit ;
esttab est1 est2 est3 est4 using "$OUT/DD_fertility.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean pmean rmean, fmt(%9.0gc %5.3f)
      label("\\ Observations" "Mean of Dependent Variable"
            "Mean of Dependent Variable (Mexico DF)"
            "Mean of Dependent Variable (Regressive States)"));
#delimit cr
estimates clear
restore

********************************************************************************
*** (7) Event study
********************************************************************************
keep if year>=2001
bys estado (year): gen sumRegres = sum(regressive)
gen yR = year if sumRegres == 1
bys estado: egen yearRegress = max(yR)
gen yeartoRegress = year - yearRegress
gen yeartoILE     = year-2007 if estado==9
gen preILE        = yeartoILE<0
gen preRegress    = yeartoRegress<0


foreach num of numlist 0(1)8 {
    gen regressiveN`num'  = yeartoRegress ==-`num'
    gen regressiveP`num'  = yeartoRegress ==`num'
    gen progressiveN`num' = yeartoILE     ==-`num'
    gen progressiveP`num' = yeartoILE     ==`num'
}
drop regressiveN0 progressiveN0 regressiveN1 progressiveN1


cap gen haemorrhagePop     = haemorrhage/population*1000
cap gen abortionRelatedPop = abortionRelated/population*1000
cap gen maternalDeathPop   = maternalDeath/population*100000
cap gen abortiveDeathPop   = abortiveDeath/population*100000
cap gen birthPop           = birth/population*1000
cap gen familyViolencePop  = familyViolence/population*1000


#delimit ;
local morbLLr regressiveN5 regressiveN4 regressiveN3 regressiveN2
regressiveP0 regressiveP1 regressiveP2 regressiveP3 regressiveP4 regressiveP5
regressiveP6 regressiveP7;
local morbLLp progressiveN3 progressiveN2 progressiveP0 progressiveP1 progressiveP2
progressiveP3 progressiveP4 progressiveP5 progressiveP6 progressiveP7 progressiveP8;
local mortLLr regressiveN8 regressiveN7 regressiveN6 regressiveN5 regressiveN4
regressiveN3 regressiveN2 regressiveP0 regressiveP1 regressiveP2 regressiveP3
regressiveP4 regressiveP5 regressiveP6 regressiveP7 regressiveP8;
local mortLLp progressiveN6 progressiveN5 progressiveN4 progressiveN3 progressiveN2
progressiveP0 progressiveP1 progressiveP2 progressiveP3 progressiveP4 progressiveP5
progressiveP6 progressiveP7 progressiveP8;
local fertLLr regressiveN8 regressiveN7 regressiveN6 regressiveN5 regressiveN4
regressiveN3 regressiveN2 regressiveP0 regressiveP1 regressiveP2 regressiveP3
regressiveP4 regressiveP5;
local fertLLp progressiveN6 progressiveN5 progressiveN4 progressiveN3 progressiveN2
progressiveP0 progressiveP1 progressiveP2 progressiveP3 progressiveP4 progressiveP5
progressiveP6;
#delimit cr

cap gen ReformClose = estado==15&year>=2007
local wt [aw=population]
local X          poverty accesshealth aveschool womenac avesalary SP 
regress haemorrhagePop ReformClose i.estado i.year `morbLLr' `morbLLp' `X' `wt', cluster(estado)

gen EST_r = .
gen LB_r  = .
gen UB_r  = .
gen NUM_r = .
gen EST_p = .
gen LB_p  = .
gen UB_p  = .
gen NUM_p = .
local j=1
foreach var of varlist `morbLLr' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_r = _b[`var'] in `j'
    replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_r = `j'-6 in `j'
    if `j'==4 {
        local ++j
        replace NUM_r = `j'-6 in `j'
        replace LB_r = 0  in `j'
        replace UB_r = 0 in `j'
    }
    local ++j
}
local j=1
foreach var of varlist `morbLLp' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_p = _b[`var'] in `j'
    replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_p = `j'-4 in `j'
    if `j'==2 {
        local ++j
        replace NUM_p = `j'-4 in `j'
        replace LB_p = 0 in `j'
        replace UB_p = 0 in `j'
    }
    local ++j
}
#delimit ;
twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) ylabel(-2(0.5)0.5)
xlabel(-3(1)8) ytitle("Haemorrhage Morbidity per 1,000 Women")
legend(order(2 "Point Estimate" 1 "95% CI")) xtitle("Time to Reform");
graph export "$OUT/morbidity/event_haemorrhage_progressive.eps", replace;

twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) ylabel(-2(0.5)0.5)
xlabel(-5(1)7) ytitle("Haemorrhage Morbidity per 1,000 Women")
legend(order(2 "Point Estimate" 1 "95% CI")) xtitle("Time to Reform");
graph export "$OUT/morbidity/event_haemorrhage_regressive.eps", replace;
#delimit cr
drop EST_* LB_* UB_* NUM_*


regress abortionRelatedPop ReformClose i.estado i.year `morbLLr' `morbLLp' `X' `wt', cluster(estado)

gen EST_r = .
gen LB_r  = .
gen UB_r  = .
gen NUM_r = .
gen EST_p = .
gen LB_p  = .
gen UB_p  = .
gen NUM_p = .
local j=1
foreach var of varlist `morbLLr' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_r = _b[`var'] in `j'
    replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_r = `j'-6 in `j'
    if `j'==4 {
        local ++j
        replace NUM_r = `j'-6 in `j'
        replace LB_r = 0  in `j'
        replace UB_r = 0 in `j'
    }
    local ++j
}
local j=1
foreach var of varlist `morbLLp' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_p = _b[`var'] in `j'
    replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_p = `j'-4 in `j'
    if `j'==2 {
        local ++j
        replace NUM_p = `j'-4 in `j'
        replace LB_p = 0 in `j'
        replace UB_p = 0 in `j'
    }
    local ++j
}
#delimit ;
twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) ylabel(-4(2)2)
xlabel(-3(1)8) ytitle("Abortion Related Morbidity per 1,000 Women")
xtitle("Time to Reform") legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/morbidity/event_abortionRelated_progressive.eps", replace;

twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) ylabel(-4(2)2)
xlabel(-5(1)7) ytitle("Abortion Related Morbidity per 1,000 Women")
xtitle("Time to Reform") legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/morbidity/event_abortionRelated_regressive.eps", replace;
#delimit cr
drop EST_* LB_* UB_* NUM_*

regress maternalDeathPop ReformClose i.estado i.year `mortLLr' `mortLLp' `X' [aw=population], cluster(estado)

gen EST_r = .
gen LB_r  = .
gen UB_r  = .
gen NUM_r = .
gen EST_p = .
gen LB_p  = .
gen UB_p  = .
gen NUM_p = .
local j=1
foreach var of varlist `mortLLr' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_r = _b[`var'] in `j'
    replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_r = `j'-9 in `j'
    if `j'==7 {
        local ++j
        replace NUM_r = `j'-9 in `j'
        replace LB_r = 0  in `j'
        replace UB_r = 0 in `j'
    }
    local ++j
}
local j=1
foreach var of varlist `mortLLp' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_p = _b[`var'] in `j'
    replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_p = `j'-7 in `j'
    if `j'==5 {
        local ++j
        replace NUM_p = `j'-7 in `j'
        replace LB_p = 0 in `j'
        replace UB_p = 0 in `j'
    }
    local ++j
}
#delimit ;
twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) ylabel(-2(1)3)
xlabel(-6(1)8) ytitle("Maternal Deaths per 100,000 Women")
xtitle("Time to Reform") legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/mortality/event_maternal_progressive.eps", replace;

twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) 
xlabel(-8(1)8) ytitle("Maternal Deaths per 100,000 Women") ylabel(-2(1)3)
xtitle("Time to Reform") legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/mortality/event_maternal_regressive.eps", replace;
#delimit cr
drop EST_* LB_* UB_* NUM_*

regress abortiveDeathPop ReformClose i.estado i.year `mortLLr' `mortLLp' `X' `wt', cluster(estado)
gen EST_r = .
gen LB_r  = .
gen UB_r  = .
gen NUM_r = .
gen EST_p = .
gen LB_p  = .
gen UB_p  = .
gen NUM_p = .
local j=1
foreach var of varlist `mortLLr' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_r = _b[`var'] in `j'
    replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_r = `j'-9 in `j'
    if `j'==7 {
        local ++j
        replace NUM_r = `j'-9 in `j'
        replace LB_r = 0  in `j'
        replace UB_r = 0 in `j'
    }
    local ++j
}
local j=1
foreach var of varlist `mortLLp' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_p = _b[`var'] in `j'
    replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_p = `j'-7 in `j'
    if `j'==5 {
        local ++j
        replace NUM_p = `j'-7 in `j'
        replace LB_p = 0 in `j'
        replace UB_p = 0 in `j'
    }
    local ++j
}
#delimit ;
twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) 
xlabel(-6(1)8) ytitle("Abortive Deaths per 100,000 Women")
xtitle("Time to Reform") ylabel(-0.4(0.2)0.4)
legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/mortality/event_abortive_progressive.eps", replace;

twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon))
ytitle("Abortive Deaths per 100,000 Women") xlabel(-8(1)7)
xtitle("Time to Reform") ylabel(-0.4(0.2)0.4)
legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/mortality/event_abortive_regressive.eps", replace;
#delimit cr
drop EST_* LB_* UB_* NUM_*



cap drop fertPop
gen fertPop = birth/population*1000
cap gen treat = estado == 9
foreach yr of numlist 2001(1)2006 {
    gen morbtemp = fertPop if year==`yr'
    bys stateNum: egen mAve`yr'=mean(morbtemp)
    drop morbtemp
}
ebalance treat mAve2001 mAve2002 mAve2003 mAve2004 mAve2005 mAve2006, gen(entropyWt) tolerance(25)
ebalance treat mAve2001 mAve2002 mAve2003 mAve2004 mAve2005 mAve2006, basewt(population) gen(eWtPop) tolerance(25)

regress fertPop ReformClose i.estado i.year `fertLLp' `fertLLr' `X' [aw=eWtPop], cluster(estado)

gen EST_r = .
gen LB_r  = .
gen UB_r  = .
gen NUM_r = .
gen EST_p = .
gen LB_p  = .
gen UB_p  = .
gen NUM_p = .
local j=1
foreach var of varlist `fertLLr' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_r = _b[`var'] in `j'
    replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_r = `j'-9 in `j'
    if `j'==7 {
        local ++j
        replace NUM_r = `j'-9 in `j'
        replace LB_r = 0  in `j'
        replace UB_r = 0 in `j'
    }
    local ++j
}
local j=1
foreach var of varlist `fertLLp' {
    boottest `var'=0, boottype(wild) seed(22)
    local se = _b[`var']/r(t)
    replace EST_p = _b[`var'] in `j'
    replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
    replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
    replace NUM_p = `j'-7 in `j'
    if `j'==5 {
        local ++j
        replace NUM_p = `j'-7 in `j'
        replace LB_p = 0 in `j'
        replace UB_p = 0 in `j'
    }
    local ++j
}
#delimit ;
twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) 
xlabel(-6(1)6) xtitle("Time to Reform") ytitle("Births per 1,000 Women")
legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/fertility/event_fertility_progressive.eps", replace;

twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9)) 
scheme(s1mono) yline(0, lcolor(maroon)) 
xlabel(-8(1)5) xtitle("Time to Reform") ytitle("Births per 1,000 Women")
legend(order(2 "Point Estimate" 1 "95% CI"));
graph export "$OUT/fertility/event_fertility_regressive.eps", replace;
#delimit cr
drop EST_* LB_* UB_* NUM_*





********************************************************************************
*** (8) Longer plots (SAEH only)
********************************************************************************
use "$POP/populationStateYear", clear
drop month
reshape long year_, i(stateName Age stateNum) j(Year)
rename year_ population
keep if Age>=15&Age<=44
collapse (sum) population, by(stateName stateNum Year)
rename Year year
keep if year>=2000&year<=2016

#delimit ;
local snum 29 12 09 17 03 28 10 01 32 04 22 14 26 07 25 16 30 23 13 05 21 27
19 15 18 02 24 06 31 11 20 08;
#delimit cr

gen estado = .
local i = 1
foreach num in `snum' {
    replace estado = `i' if stateNum=="`num'"
    local ++i
}
tempfile pop
save `pop'

use  "$DAT/morbiditySAEH_month.dta"
 local gvars `amorb' deliveries haemorrhage totalNonBirth days_haemorrhage totalONonBirth
gen state = 1 if estado == 9
replace state=2 if regressiveState==1
replace state=0 if state==.



preserve
collapse (sum) `gvars', by(year state)

local l1 lwidth(medthick) lcolor(black) 
local l2 lwidth(medthick) lcolor(gs8) lpattern(dash)
local l3 lwidth(medium) lcolor(gs12) lpattern(longdash)  

foreach var of varlist `gvars' {
    #delimit ;
    twoway line `var' year if state==1, yaxis(1) `l1'
    ||     line `var' year if state==0, yaxis(2) `l2'
    ||     line `var' year if state==2, yaxis(2) `l3'
    legend(label(1 "DF") label(2 "Other states") label(3 "Regressive"))
    xline(2007.33, lcolor(red)) xtitle("Year")  ytitle("Discharges DF")
    scheme(LF3) ytitle("Discharges other states", axis(2)) xsize(4.5); 
    graph export "$OUT/SAEH/`var'trend-year.eps", replace as(eps);
    #delimit cr

}
restore

collapse (sum) `gvars', by(year estado)
merge 1:1 year estado using `pop'
xtset estado year

drop if _merge==2
foreach var of varlist abortionRelated haemorrhage {
    gen Pop`var'=`var'/population*1000

    #delimit ; 
    synth Pop`var' Pop`var'(2000) Pop`var'(2001) Pop`var'(2002) Pop`var'(2003)
    Pop`var'(2004) Pop`var'(2005) Pop`var'(2006), trunit(9) trperiod(2007);
    matrix A = [e(Y_treated), e(Y_synthetic)];
    
    svmat A, names(synth);
    gen yearS = 1999+_n in 1/15;
    twoway line synth1 yearS, lwidth(thick) ||
           line synth2 yearS, lwidth(thick) lpatter(dash) xline(2007)
    scheme(LF3) xtitle(Year) ytitle("Rate of `name' per 1,000 Women")
    legend(order(1 "Treatment (D.F.)" 2 "Synthetic Control") size(large));
    graph export "$OUT/SAEHsynth`var'.eps", replace;
    
    gen DifReal = synth1-synth2;
    drop synth1 synth2;
    #delimit cr
    local placebos
    foreach num of numlist 1(1)8 10(1)32 {
        #delimit ;
        dis "Round `num'";
        synth Pop`var' Pop`var'(2000) Pop`var'(2001) Pop`var'(2002) Pop`var'(2003)
        Pop`var'(2004) Pop`var'(2005) Pop`var'(2006), trunit(`num') trperiod(2007);
        matrix A = [e(Y_treated), e(Y_synthetic)];
        #delimit cr
        svmat A, names(synth)
        gen Dif`num' = synth1-synth2
        drop synth1 synth2
        local placebos `placebos' line Dif`num' yearS, lcolor(gs12) lpattern(dash) ||
   }
   #delimit ;
    twoway `placebos' line DifReal yearS, lwidth(thick) lcolor(black)
    legend(order(32 "Mexico D.F." 2 "Placebo Permutations") size(medlarge))
    xline(2007) xtitle("") scheme(LF3);
    graph export "$OUT/SAEHsynth`var'_Inference.eps", replace;
    #delimit cr
    drop yearS Dif*
}    

preserve
collapse (sum) `gvars', by(date state)


local l1 lwidth(medthick) lcolor(black) 
local l2 lwidth(medthick) lcolor(gs8) lpattern(dash)
local l3 lwidth(medium) lcolor(gs12) lpattern(longdash)  

foreach var of varlist `gvars' {
    #delimit ;
    twoway line `var' date if state==1, yaxis(1) `l1'
    ||     line `var' date if state==0, yaxis(2) `l2'
    ||     line `var' date if state==2, yaxis(2) `l3'
    legend(label(1 "DF") label(2 "Other states") label(3 "Regressive"))
    xline(2007.33, lcolor(red)) xtitle("Year")  ytitle("Discharges DF")
    scheme(LF3) ytitle("Discharges other states", axis(2)); 
    graph export "$OUT/SAEH/`var'trend-month.eps", replace as(eps);
    #delimit cr
}
restore


