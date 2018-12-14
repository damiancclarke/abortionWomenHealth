clear all

global DAT "/mnt/SDD-2/database/MexDemografia/Judiciales"
global DAT "~/database/MexDemografia/Judiciales"
global OUT "~/investigacion/2018/ILE-health/results/crime"
global LOG "~/investigacion/2018/ILE-health/log"
global POP "~/investigacion/2018/ILE-health/data/population"
local afiles
cap log close
log using "$LOG/analysisPenal.txt", replace text


********************************************************************************
*** (2) Population
********************************************************************************
use "$POP/populationStateYear", clear
drop month
reshape long year_, i(stateName Age stateNum) j(Year)
rename year_ population
keep if Age>=15&Age<=44
collapse (sum) population, by(stateName stateNum Year) fast
rename Year year
keep if year>=2003&year<=2011

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
destring stateNum, replace
tempfile population
save `population'


foreach year of numlist 2003(1)2008 {
    use "$DAT/`year'/sreg`year'", clear
    merge 1:m id_ps using "$DAT/`year'/sdel`year'"
    drop _merge
    rename b_entreg id_ent
    merge m:1 id_ent using "$DAT/`year'/CENTIDAD"
    gen aborto = b_delito == 170105
    gen abortoPrison = aborto==1&b_priva!=0
    gen abortoPrisWom = b_delito == 170105&b_sexo==2
    gen homicidio    = b_delito == 170100
    gen sentence     = 0 if b_priva==0
    replace sentence = 1/12 if b_priva==1
    replace sentence = 0.5  if b_priva==2
    replace sentence = 1.5  if b_priva==3
    replace sentence = 4    if b_priva==4
    replace sentence = 6    if b_priva==5
    replace sentence = 8    if b_priva==6
    replace sentence = 10   if b_priva==7
    replace sentence = 12   if b_priva==8
    replace sentence = 14   if b_priva==9
    replace sentence = 16   if b_priva==10
    replace sentence = 18   if b_priva==11
    replace sentence = 20   if b_priva==12
    replace sentence = 22   if b_priva==13
    gen abortTime    = sentence if aborto==1
    gen abortTimeWom    = sentence if aborto==1&b_sexo==2
    
    tab aborto
    collapse (sum) aborto abortoPris* abortTime* homicidio, by(id_ent descrip)
    gen year =  `year'
    tempfile abort`year'
    save `abort`year''
    local afiles `afiles' `abort`year''
}

foreach year of numlist 2009(1)2011 {
    use "$DAT/`year'/sreg`year'", clear
    merge 1:m id_ps using "$DAT/`year'/sdel`year'"
    drop _merge
    rename b_entreg id_ent
    merge m:1 id_ent using "$DAT/`year'/CENTIDAD"
    gen aborto = b_delito==111300|b_delito==111301|b_delito==111302|b_delito==111399
    gen homicidio = b_delito == 111102|b_delito == 111100|b_delito == 111101|b_delito == 111103
    gen abortoPrison = aborto==1&b_priva!=0
    gen abortoPrisWom = b_delito == 170105&b_sexo==2
    gen sentence     = 0 if b_priva==0
    replace sentence = 1/12 if b_priva==1
    replace sentence = 0.5  if b_priva==2
    replace sentence = 1.5  if b_priva==3
    replace sentence = 4    if b_priva==4
    replace sentence = 6    if b_priva==5
    replace sentence = 8    if b_priva==6
    replace sentence = 10   if b_priva==7
    replace sentence = 12   if b_priva==8
    replace sentence = 14   if b_priva==9
    replace sentence = 16   if b_priva==10
    replace sentence = 18   if b_priva==11
    replace sentence = 20   if b_priva==12
    replace sentence = 22   if b_priva==13
    gen abortTime    = sentence if aborto==1
    gen abortTimeWom    = sentence if aborto==1&b_sexo==2

    collapse (sum) aborto abortoPris* abortTime* homicidio, by(id_ent descrip)
    gen year =  `year'
    tempfile abort`year'
    save `abort`year''
    local afiles `afiles' `abort`year''
}

clear
append using `afiles', force
drop if id_ent>32
gen state = id_ent == 9
replace state = 2 if id_ent==2|id_ent==6|id_ent==7|id_ent==8
replace state = 2 if id_ent==10|id_ent==11|id_ent==14|id_ent==17
replace state = 2 if id_ent==18|id_ent==20|id_ent==21|id_ent==22
replace state = 2 if id_ent==23|id_ent==24|id_ent==26|id_ent==28
replace state = 2 if id_ent==30|id_ent==31

rename descrip stateName
rename id_ent estado
merge 1:1 year estado using `population'

preserve
collapse (sum) aborto abortoPrison abortTime homicidio population, by(state year)

gen meanTimeA  = abortTime/abortoPrison
gen meanTime   = abortTime/aborto
gen prisonRate = abortoPrison/aborto 
gen abortoPop  = abortoPrison/population

foreach var of varlist aborto abortoPrison abortTime meanTime* prisonRate homicidio abortoPop {
    if `"`var'"'=="aborto"       local ytit "Number of Individuals Sentenced for Abortion"
    if `"`var'"'=="abortoPrison" local ytit "Number of Individuals Sentenced to Prison for Abortion"
    if `"`var'"'=="abortTime"    local ytit "Total Number of Years Prison Sentences for Abortion"
    if `"`var'"'=="meanTime"     local ytit "Average Prison Sentence Length"
    if `"`var'"'=="meanTimeA"    local ytit "Average Prison Sentence Length for Sentences"
    if `"`var'"'=="prisonRate"   local ytit "Proportion of Sentences Resulting in Prison"
    
    #delimit ;
    twoway line `var' year if state==1, lwidth(thick)
    ||     line `var' year if state==0, lwidth(thick) lpattern(dash) 
    ||     line `var' year if state==2, lwidth(thick) lpattern(longdash)
    ytitle(`ytit') xtitle("Year") xlabel(2003(2)2011) xline(2007) scheme(LF3)
    legend(order(1 "Mexico D.F." 3 "Regressive" 2 "Other") size(large));
    graph export "$OUT/sentenced_`var'.eps", replace;
    #delimit cr
}
restore



gen meanTimeA  = abortTime/abortoPrison
gen meanTimeAW = abortTimeWom/abortoPrisWom
gen meanTime   = abortTime/aborto
gen prisonRate = abortoPrison/aborto 

replace stateName = subinstr(stateName, " ", "", .)
replace stateName = subinstr(stateName, "á", "a", .)
replace stateName = "Veracruz"      if stateName=="VeracruzdeIgnaciodelaLlave"
replace stateName = "Queretaro"     if regexm(stateName, "Quer")
replace stateName = "SanLuisPotosi" if regexm(stateName,"SanLuisPotos")
replace stateName = "Yucatan"       if regexm(stateName,"Yucat")

#delimit;
gen regressiveState=stateName=="BajaCalifornia"|stateName=="Chiapas"
|stateName=="Chihuahua"|stateName=="Colima"|stateName=="Durango"
|stateName=="Guanajuato"|stateName=="Jalisco"|stateName=="Morelos"
|stateName=="Nayarit"|stateName=="Oaxaca"|stateName=="Puebla"
|stateName=="Queretaro"|stateName=="QuintanaRoo"|stateName=="SanLuisPotosi"
|stateName=="Sonora"|stateName=="Tamaulipas"|stateName=="Yucatan"
|stateName=="Veracruz"|stateName=="Campeche";
#delimit cr
generat regressive = 1 if year >= 2008 & stateName=="BajaCalifornia"
replace regressive = 1 if year >= 2009 & stateName=="Chiapas"
replace regressive = 1 if year >= 2008 & stateName=="Chihuahua"
replace regressive = 1 if year >= 2009 & stateName=="Colima"
replace regressive = 1 if year >= 2009 & stateName=="Durango"
replace regressive = 1 if year >= 2009 & stateName=="Guanajuato"
replace regressive = 1 if year >= 2009 & stateName=="Jalisco"
replace regressive = 1 if year >= 2008 & stateName=="Morelos"
replace regressive = 1 if year >= 2009 & stateName=="Nayarit"
replace regressive = 1 if year >= 2009 & stateName=="Oaxaca"
replace regressive = 1 if year >= 2009 & stateName=="Puebla"
replace regressive = 1 if year >= 2009 & stateName=="Queretaro"
replace regressive = 1 if year >= 2009 & stateName=="QuintanaRoo"
replace regressive = 1 if year >= 2009 & stateName=="SanLuisPotosi"
replace regressive = 1 if year >= 2009 & stateName=="Sonora"
replace regressive = 1 if year >= 2009 & stateName=="Tamaulipas"
replace regressive = 1 if year >= 2009 & stateName=="Yucatan"
replace regressive = 1 if year >= 2009 & stateName=="Veracruz"
*replace regressive = 1 if year >= 2010 & stateName=="Campeche"
replace regressive = 0 if regressive!=1
gen ILE = estado==9&year>=2007
gen DF = estado == 9
gen ReformClose = estado==15&year>=2007

local pwt        [aw=population]
local Treat      ILE regressive
local FE         i.year i.estado ReformClose
local trend      i.estado#c.year
local se         cluster(estado)

gen treat = estado == 9
foreach var in abortoPrison meanTimeA abortoPrisWom meanTimeAW {

    regress `var' `Treat' `FE', cluster(estado)
    sum `var'
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

    regress `var' `Treat' `FE' [aw=population], cluster(estado)
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
esttab est1 est2 est3 est4 using "$OUT/DD_crime.tex",
b(%-9.3f) se(%-9.3f) noobs keep(`Treat') nonotes nogaps
mlabels(, none) nonumbers style(tex) fragment replace noline label
starlevel ("*" 0.10 "**" 0.05 "***" 0.01)
stats(N mean, fmt(%9.0gc %5.3f) label("\\ Observations" "Mean of Dependent Variable"));
#delimit cr
estimates clear


bys estado (year): gen sumRegres = sum(regressive)
gen yR = year if sumRegres == 1
bys estado: egen yearRegress = max(yR)
gen yeartoRegress = year - yearRegress
gen yeartoILE     = year-2007 if estado==9

foreach num of numlist 0(1)7 {
    gen regressiveN`num'  = yeartoRegress ==-`num'
    gen regressiveP`num'  = yeartoRegress ==`num'
    gen progressiveN`num' = yeartoILE     ==-`num'
    gen progressiveP`num' = yeartoILE     ==`num'
}
drop regressiveN0 progressiveN0 regressiveN1 progressiveN1
drop progressiveN5 progressiveN6 progressiveN7
drop progressiveP5 progressiveP6 progressiveP7
drop regressiveP4 regressiveP5 regressiveP6 regressiveP7


#delimit ;
local crimLLr regressiveN7 regressiveN6 regressiveN5 regressiveN4 regressiveN3
regressiveN2 regressiveP0 regressiveP1 regressiveP2;
local crimLLr regressiveN6 regressiveN5 regressiveN4 regressiveN3 regressiveN2
regressiveP0 regressiveP1 regressiveP2 regressiveP3;
local crimLLp progressiveN4 progressiveN3 progressiveN2 progressiveP0 progressiveP1
progressiveP2 progressiveP3 progressiveP4;
#delimit cr

local wt [aw=population]
local wt

foreach yvar of varlist abortoPrison meanTimeA {
    regress `yvar' i.estado i.year `crimLLr' `crimLLp' `wt', cluster(estado)
    gen EST_r = .
    gen LB_r  = .
    gen UB_r  = .
    gen NUM_r = .
    gen EST_p = .
    gen LB_p  = .
    gen UB_p  = .
    gen NUM_p = .
    local j=1
    foreach var of varlist `crimLLr' {
        boottest `var'=0, boottype(wild) seed(22)
        local se = _b[`var']/r(t)
        replace EST_r = _b[`var'] in `j'
        replace LB_r  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
        replace UB_r  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
        replace NUM_r = `j'-7 in `j'
        if `j'==5 {
            local ++j
            replace NUM_r = `j'-7 in `j'
            replace LB_r = 0  in `j'
            replace UB_r = 0 in `j'
        }
        local ++j
    }
    local j=1
    foreach var of varlist `crimLLp' {
        cap boottest `var'=0, boottype(wild) seed(22)
        local se = _b[`var']/r(t)
        cap replace EST_p = _b[`var'] in `j'
        cap replace LB_p  = _b[`var']-invttail(e(df_r),0.025)*`se' in `j'
        cap replace UB_p  = _b[`var']+invttail(e(df_r),0.025)*`se' in `j'
        replace NUM_p = `j'-5 in `j'
        if `j'==3 {
            local ++j
            cap replace NUM_p = `j'-5 in `j'
            cap replace LB_p = 0 in `j'
            cap replace UB_p = 0 in `j'
        }
        local ++j
        local se=0
    }
    #delimit ;
    twoway rarea LB_p UB_p NUM_p, color(gs14)
    || scatter EST_p NUM_p, ms(oh) xline(-1, lpattern(dash) lcolor(gs9))
    scheme(s1mono) yline(0, lcolor(maroon))
    xlabel(-4(1)4) xtitle("Time to Reform")
    legend(order(2 "Point Estimate" 1 "95% CI"));
    graph export "$OUT/event_`yvar'_progressive.eps", replace;
    
    twoway rarea LB_r UB_r NUM_r, color(gs14)
    || scatter EST_r NUM_r, ms(oh) xline(-1, lpattern(dash) lcolor(gs9))
    scheme(s1mono) yline(0, lcolor(maroon))
    xlabel(-6(1)3) xtitle("Time to Reform")
    legend(order(2 "Point Estimate" 1 "95% CI"));
    graph export "$OUT/event_`yvar'_regressive.eps", replace;
    #delimit cr
    drop EST_* LB_* UB_* NUM_*
} 
