
library(JABBA)
library(tidyverse)
File = "~/DOCAS/Krill_Spatial_JABBA" # LINK to your folder of choice here

df <- read_csv("~/DOCAS/Krill_Spatial_JABBA/data_krill_jabba.csv") %>% 
  filter(Year>2000,
         Year<2019)

# or

yr = 2001:2018
ct = c(4981 , 72060 , 15427 , 46456 , 73494   ,3102 , 65591 ,
       93384  ,91855  ,49999 ,115995,  29040,
       31306,  72455,  17101,  34302,  69046, 137880)
it = c(4.163482 , 6.377938  ,5.436893,  4.465801,  2.882375, 11.189135,
       9.716262  ,3.674545, 10.056334, 12.419098,
       8.263407,  7.026917,  8.643829 , 9.527634,  8.466477 , 8.907962,
       8.936349, 10.324057)
se = rep(0.3, 18)
df = data.frame(year=yr,ct=ct,bacu=it,itse=se)

assessment = "KrillSP"
output.dir = file.path(File,assessment)
dir.create(output.dir,showWarnings = F)
setwd(output.dir)

# Prepara los datos de huepo ----------------------------------------------
cpue = df[,c(1,3)]
colnames(cpue) = c("Year", "Bv")
se = df[,c(1,4)]
colnames(se) = c("Year", "Bv")
catch = df[,c(1,2)]
colnames(catch) = c("Year","Total")
sau <- list()
sau$cpue <- cpue
sau$se <- se
sau$catch <- catch

# Compile JABBA JAGS model and input object
m1_input = build_jabba(catch=sau$catch,
                       cpue=sau$cpue,
                       se=sau$se,
                       assessment="caso 1",
                       scenario = "Fox",
                       model.type = "Fox",
                       sigma.est = FALSE,
                       igamma = c(0.001,0.001))
# Check input
jbplot_indices(m1_input)


# Fit JABBA (here mostly default value - careful)
sau1 = fit_jabba(m1_input,quickmcmc = TRUE) # quick run

head(sau1$kobe)

# Make individual plots
jbplot_catch(sau1)
jbplot_catcherror(sau1)
jbplot_ppdist(sau1)
jbplot_mcmc(sau1)
jbplot_residuals(sau1)
jbplot_cpuefits(sau1)
jbplot_runstest(sau1)
jbplot_logfits(sau1)
jbplot_procdev(sau1)
jbplot_PPC(sau1) # Posterior Predictive Checks - Not great should 0.2-0.8

# Status
jbplot_summary(sau1)
# combine plots
jbpar(mfrow=c(2,2))
jbplot_summary(sau1,add=T,type = c("BBmsy", "FFmsy"))
jbplot_spphase(sau1,add=T)
jbplot_kobe(sau1,add=T)

jbpar(mfrow=c(3,2),plot.cex = 0.8)
jbplot_ensemble(sau1)

# Try to improve runs test diagnostics by changing the variance settings
# Increase minimum obs error from 0.01 to 0.1 and remove SEs from CPUE model
jbinput2 = build_jabba(catch=bet$catch,cpue=bet$cpue,se=NULL,assessment=assessment,
                       scenario = "Run2",model.type = "Fox",sigma.est = TRUE,fixed.obsE = 0.1,igamma = c(0.001,0.001),
                       psi.prior = c(1,0.2), # Initial depletion B/K
                       verbose = F)


bet2 = fit_jabba(jbinput2,quickmcmc = T)
# Check residual diags
jbplot_cpuefits(bet2)
jbplot_runstest(bet2)
jbplot_logfits(bet2)
jbplot_PPC(bet2)
# Improved
refinput = jbinput2 # Note as reference input 

# Compare
jbplot_summary(list(Run1=sau1,Run2=bet2))
jbplot_ensemble(list(Run1=sau1,Run2=bet2))

# Check parameters and convergence (p <0.05 is not fully converged)
bet2$pars 
# Make a long MCMC run with 3 chains
bet.full = fit_jabba(jbinput2,nc=3)

# MCMC convergence
bet.full$pars 
jbplot_mcmc(bet.full)

# get quantaties
bet.full$estimates
# FLR data.frame trajectories
bet.full$flqs
# fits
bet.full$diags


#------------------------------------------------------
# Estimate shape m as function of Bmsy/K
#-------------------------------------------------------

# Compile JABBA JAGS model and input object
jbinput3 = build_jabba(catch=bet$catch,cpue=bet$cpue,se=NULL,assessment=assessment,
                       scenario = "Est.Shape",model.type = "Pella_m", # Estimate shape
                       BmsyK=0.4, # mean 40%B0
                       shape.CV = 0.3, #CV
                       sigma.est = TRUE,
                       fixed.obsE = 0.1,
                       igamma = c(0.001,0.001),
                       psi.prior = c(1,0.1))

bet3 = fit_jabba(jbinput3,quickmcmc=F)

jbplot_ppdist(bet3) # check shape prior & posterior dist - not much information
# Compare
jbplot_summary(list(bet2,bet3))
jbplot_ensemble(list(bet2,bet3))

# also run model as Schaefer
jbinput4 = build_jabba(catch=bet$catch,cpue=bet$cpue,se=NULL,assessment=assessment,
                       scenario = "Schaefer",model.type = "Schaefer", # Estimate shape
                       sigma.est = TRUE,
                       fixed.obsE = 0.1,
                       igamma = c(0.001,0.001),
                       psi.prior = c(1,0.1))

bet4 = fit_jabba(jbinput4,quickmcmc=T)

# Compare 
jbpar(mfrow=c(3,2),plot.cex=0.7)
jbplot_ensemble(list(sau1,bet2,bet3,bet4))
jbpar(mfrow=c(3,2),plot.cex=0.6)
jbplot_summary(list(sau1,bet2,bet3,bet4),add=T)

#----------------------------------------------------
# Do some forecasting
#----------------------------------------------------

# F-based forecasting
# Relative Fmsy
# Single Forecast for Base-Case model - now works with imp.yr=1 
fw1 = fw_jabba(bet2,nyears=10,imp.yr=1,imp.values = seq(0.8,1.2,0.1),quant="F",type="msy",stochastic = T)
#jbpar(mfrow=c(3,2))
jbpar(mfrow=c(3,2),plot.cex = 0.7)
jbplot_ensemble(fw1)
# Zoom-in
jbplot_ensemble(fw1,xlim=c(2010,2027))
abline(v=2018) # Check
# Forecast with AR1 process error
fw1.ar1 = fw_jabba(bet2,nyears=10,imp.yr=1,quant="F",type="msy",AR1=TRUE,stochastic = T)
# now compare
jbpar(mfrow=c(3,2),plot.cex = 0.6)
for(i in 1:3){
  jbplot_ensemble(fw1,subplots = c(1,2,5)[i],add=T,xlim=c(2010,2028),legend=ifelse(i==1,T,F))
  jbplot_ensemble(fw1.ar1,subplots = c(1,2,5)[i],add=T,xlim=c(2010,2028),legend=ifelse(i==1,T,F))
}
mtext(c("Default","AR1"),outer=T,at=c(0.27,0.77))

# IOTC-Style: Relative current catch (default mean 3 yrs)
# 10 years, 2 intermediate years, deterministic
fw.io = fw_jabba(bet2,nyears=10,imp.yr=3,imp.values = seq(0.6,1.2,0.1),quant="Catch",type="ratio",nsq=3,stochastic = F)
jbplot_ensemble(fw.io)
jbpar(mfrow=c(2,2))
jbplot_ensemble(fw.io,add=T,subplots = 1,legend.loc = "topright")
jbplot_ensemble(fw.io,add=T,subplots = 2,legend=F)
jbplot_ensemble(fw.io,add=T,subplots = 5,legend=F)
jbplot_ensemble(fw.io,add=T,subplots = 6,legend=F)

# ICCAT Style
Ccur = mean(tail(jbinput2$data$catch[,2],2))
TACs = c(75500,seq(60000,78000,2000))
fw.iccat= fw_jabba(bet2,nyears=10,imp.yr=3,initial = c(Ccur,76000),imp.values = TACs,quant="Catch",type="abs",nsq=3,stochastic = F,AR1=T)

jbpar(mfrow=c(2,2))
jbplot_ensemble(fw.iccat,legendcex = 0.4,xlim=c(2010,2027),subplots = c(1,2,5,6),add=T)
jbplot_ensemble(fw.iccat,legendcex = 0.4,xlim=c(2010,2027),subplots = c(1,2,5,6),plotCIs = F)

# Check if correct
jbpar()
jbplot_ensemble(fw.iccat,legendcex = 0.4,xlim=c(2010,2027),subplots = c(6),plotCIs = F,add=T)
abline(v=c(2017,2018,2019,2020)) # 2020 = imp.yr

# Do Ensemble modelling
jbplot_ensemble(list(bet2,bet3,bet4))

# Joint all runs
ens = jbplot_ensemble(list(bet2,bet3,bet4),kbout=T,joint=T)

# Do ensemble forecast

fw.ens= fw_jabba(list(bet2,bet3,bet4),nyears=10,imp.yr=2,initial = Ccur,imp.values = TACs,quant="Catch",type="abs",nsq=3,stochastic = F,AR1=T,thin=3)
jbpar(mfrow=c(3,2),plot.cex = 0.6)
for(i in 1:6) jbplot_ensemble(fw.ens,add=T,subplots = i,legend = ifelse(i==2,T,F))


#----------------------------------------------------------------
# Conduct Retrospective Analysis and Hind-Cast Cross-Validation
#----------------------------------------------------------------

# Do hindcast cross-validation
hc1 = hindcast_jabba(jbinput2,bet2,peels=1:5)

# Show Retrospective Pattern
mohns= jbplot_retro(hc1)

mohns
mohns[row.names(mohns)=="rho.mu",]

hindcasts = hc1
# Make alternative forecasts
hc2 = jbhcxval(hc1,AR1=T) # make forecasts with AR1

jbpar(mfrow=c(1,2))
for(i in 1:1){
  jbplot_hcxval(hc1,index=c(2)[i],add=T,minyr = 2000,legend.add = F)
  jbplot_hcxval(hc2,index=c(2)[i],add=T,minyr = 2000,legend.add = F)
}
mtext(c("Default","AR1"),outer=T,at=c(0.27,0.77))

jbmase(hc2)

#------------------------------------------------------
# Catch-Only with biomass prior in 2010 as type B/Bmsy
#------------------------------------------------------
# Compile JABBA JAGS model and input object for Catch Only
# Add biomass prior based on B/Bmsy guestimate
jbinput5 = build_jabba(catch=bet$catch,model.type = "Fox",
                       assessment=assessment,scenario =  "CatchOnly" ,
                       b.prior=c(0.5,0.2,2010,"bbmsy"),
                       psi.prior = c(1,0.1))


# Fit JABBA
bet5 = fit_jabba(jbinput5,save.jabba=TRUE,output.dir=output.dir)

# Check depletion prior vs posterior
jbplot_bprior(bet5)
# Compare
jbplot_summary(list(bet2,bet5))



#><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>
# Original South Atlantic Swordfish example here
# Winker et al. (2018). JABBA: Just Another Biomass Assessment
#><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>><>
swos = iccat$swos

assessment = "SWOSiccat"
scenario = "Base"
output.dir = file.path(File,assessment)
dir.create(output.dir,showWarnings = F)
setwd(output.dir)

# Compile JABBA JAGS model and input object
jbswos = build_jabba(catch=swos$catch,cpue=normIndex(swos$cpue),se=swos$se,assessment=assessment,scenario = scenario,
                     model.type = "Pella",
                     BmsyK = 0.4,
                     r.prior=c(0.42,0.37),
                     K.prior = c(250000,1),
                     psi.prior = c(1,0.25),
                     fixed.obsE = 0.2,
                     add.catch.CV = FALSE,
                     proc.dev.all = FALSE, 
                     igamma=c(4,0.01), # default process error (moderately informative)
                     P_bound = c(0.02,1.1),verbose=FALSE)

jbplot_indices(jbswos)

# fit JABBA
fit.swos = fit_jabba(jbswos,save.jabba=TRUE,output.dir=output.dir)

jbplot_cpuefits(fit.swos)
jbplot_logfits(fit.swos)