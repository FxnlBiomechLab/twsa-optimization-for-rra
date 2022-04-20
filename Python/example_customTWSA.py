

# %% load the class
import reduceresiduals

# %% setup some variables
# update trial path to match where the test data is saved on your system       
trialpath = "C:/Users/Jordan/Documents/PhD/rra_tools/rra-optimization/HamnerOpt/subject01/Run_40002/Trial_1" # full path to trial folder. must contain scaled model, and ik data
participant = "Hamner2010_v4_subject01" # first part of the model name
condition = [] #empty for this test data, but is otherwise the second part of the model name constructed as "participant_condition.osim"

# %% initialize an instance of the class
rraopts = reduceresiduals.rrasetup( trialpath, participant, condition )


# %% set properties different from defaults
rraopts.fileset.kinfile = "Run_40002_IK.mot"
rraopts.fileset.grffile = "Run_40002_GRF.mot"
rraopts.toolsettings.kinfile = rraopts.fileset.kinfile

# %% specify the reserve actuator (joint torques) and residual actuators optimal force 
rraopts.createReservesFile(ReserveForce=2000, ResidualForce=75)

# %% first pass at RRA. Want to write clean tasks, reserves, and external loads specifications files 
rraopts.initialRRA(createTasks = True, createReserves = False, createExtLoads = True)

# %% perform the mass adjustment iterations
rraopts.runMassItrsRRA()

# %% optional calculate the peak external force (ground reaction force)
# we'll use this value as the basis for normalizing residuals in the TWSA cost function
peak_force = rraopts.readPeakExtForce()


# %% run TWSA with custom settings
rraopts.optimizeTrackingWeights(overwrite = True, min_itrs = 25, max_itrs = 75, fcn_threshold = 2, wRes = 2, wErr = 1, pRes = 3, pErr = 3, ResidualNorm = peak_force, RotationNorm = 5, TranslationNorm = 0.04)
# overwrite = True - deletes saved progress and starts the specified trial from scratch
# min_itrs = 25 - run at least 25 iterations of RRA
# max_itrs = 75 - run at most 75 iterations of RRA 
# fcn_threshold = 2 - terminate TWSA if cost function of any iteration is below this value after at least min_itrs
# wRes = 2, wErr = 1, pRes = 3, pErr = 3 - set cost function weights and polynomials
# ResidualNorm = peak_force - normalize the residuals the cost function using the peak force (5% of ResidualNorm for forces, 1% for moments) 
# RotationNorm = 5 - normalize the rotational tracking errors by 5 degrees in the cost function
# TranslationNorm = 0.04 - normalize the translational tracking errors by 4 cm in the cost function
#


# %%
