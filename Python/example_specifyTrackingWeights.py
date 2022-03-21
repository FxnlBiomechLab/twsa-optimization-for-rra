

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

myWeights = {"ankle_angle_r": 15,"ankle_angle_l": 5,"knee_angle_r": 5,"knee_angle_l": 10,"hip_flexion_r": 25,"hip_flexion_l": 10}
rraopts.createTasksFile(UserWeights=myWeights) # all other weights will be set to 1
# %% first pass at RRA. Weights are already written so we don't need to set createTasks = True
rraopts.initialRRA(createReserves = True, createExtLoads = True)

# %% can finish running the mass iterations, and TWSA below if desired
