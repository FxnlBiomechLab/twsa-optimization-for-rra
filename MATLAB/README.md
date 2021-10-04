# rra-optimization
An evolutionary algorithm-based optimization for tracking weights in the OpenSim Residual Reduction Algorithm (RRA).

## Contents
"+rraTools" - This folder contains the MATLAB classes used in the optimization scheme. The folder containing "+rraTools" needs to be in the MATLAB path. _Do not add "+rraTools" directly to the path!_ These classes are accessible to MATLAB after calling  "import rraTools.* ". 

"+rraTools\rrasetup.m" - Class containing the main attributes and methods required to perform the tracking weight optimization.
"+rraTools\rraoptions.m" - Helper class with attributes used to assign values to the required options in the OpenSim RRA tool.
"+rraTools\rrafiles.m" - Helper class with input and output filename specifications used by the RRA scheme.

To include this namespace in your code use:
```{MATLAB}
import rraTools.*
```

required MATLAB libraries:

* opensim - [installation instructions for OpenSim MATLAB libraries](https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+with+Matlab)



### Class: rrasetup 
Calling the constructor **"obj = rrasetup(trialpath, participant, condition, mass)"** returns an object initialized with file tags and folder paths specific to a single motion trial/simulation. This object posesses several methods to perform residual reduction steps as needed.
#### Methods: 
1. **initialRRA()** - optional arguments: "CreateTasks", "CreateReserves", "CreateExtLoads" all boolean with default to true. Specify with name value pairs to change from defaults. This method performs the first iteration of RRA on a  participant scaled model. 

2. **runMassItrsRRA()** - Use after the initial RRA iteration to perform model mass adjustments until the detected mass change is less than 0.001 kg. Maximum number of iterations is 10.

3. **optimizeTrackingWeights()** - Performs the tracking weight optimization algorithm using the mass adjusted model. Optional arguments: "min_itrs" integer to specify a minimum number of iterations to use (default = 25), "max_itrs" integer to specify a maximum number of iterations (default = 75), "fcn_threshold" numeric input to specify target cost function value for good enough convergence (default = 2), "wRes" numeric multiplier for the residual cost term (default = 1), "wErr" numeric multiplier for the tracking errors cost term (default = 3), "pRes" numeric polynomial power for the residual cost term (default = 3), "pErr" polynomial power for the tracking errors cost term (default = 4).

* **writeRRATool()** - short helper function that configures the RRA tool and writes the xml setup file using determined settings. Settings are specified from the attributes of "rraoptions". These attributes can be access through the rrasetup class for manual specification:  
```{MATLAB}
r = rrasetup(trialpath, participant, condition, mass);
% r.toolsettings contains rraoptions attributes for the current instance of rrasetup 
r.toolsettings.resultspath = mypath; % manually change the output directory of the RRA tool 
r.initalRRA() % run the first RRA iteration using the manually specified output directory
``` 

* **adjMass()** - short helper function called by "initialRRA" and "runMassItrsRRA" to make the recommended mass adjustments printed in the RRA log file. 

* **writeReservesFile()** - creates and writes the reserve actuators force set to an xml file. Optional arguments: "SkipCoordinates" a cell array containing character specifications of coordinates to not actuate (will be given an optimal force of 1), "ReserveForce" a numeric input to specify the optimal force for all reserves (default is 1600), "ResidualForce" a numeric input to specify the optimal force given to reserve actuators FX, FY, FZ, MX, MY, and MZ (default is 100).

* **writeTasksFile()** - creates and writes the RRA tracking task set and writes to an xml file. Optional arguments can be specified as name value pairs: "SkipCoordinates" a cell array containing character specifications of coordinates that will not be tracked (which are otherwise unconstrained), "Kp" numeric value for proportional gain of the tracking weight controller (default = 1600), "UniformWeights" a boolean to either use equal weights for all tasks (default = true), or to use stronger weights for certain coordinates (False), "UserWeights" a 2D cell array containing coordinate names in the first row and corresponding weights in the second row Names and weights should be supplied in the following syntax "{name_array; weight_array}". Note, user supplied weights are ignored if 'UniformWeights' is set to true.  
e.g.  
```{MATLAB}
writeTasksFile('UserWeights', {'ankle','knee','hip';25,10,5} )
```  

* **writeExtLoads()** - short helper that creates and writes the xml external loads configuration file based on the filenames specified in the fileset (of type rrafiles).

* Additional internal helpers and nested classes are defined, but not described here.

### Class: rrafiles
Only a constructor method exists for this class. The returned rrafiles object has the following properties.
* **trialpath** - system path to the trial folder containing the scaled model, motion, and grf files.
* **resultspath** - system path to initial RRA results location. By default is specified as *trialpath\RRA_initial*
* **adjresultspath** - system path to the mass iterations results. By default specified as *trialpath\RRA_adjMass*
* **optpath** - system path to tracking weight optimization folder. By default specified as *trialpath\RRA_optWeights*
* **finalpath** - system path to final optimized results. By default specied as *trialpath\RRA_Final*
* **modelname** - filename of participant scaled model. Uses input arguments to construct. *(participant)_(condition).osim*
* **outname** - filename of model output from RRA tool with center of mass adjustments performed. Appends "_adjMass" to modelname
* **adjname** - filename of model after mass adjustments are applied. Appends "_adj" to modelname
* **optname** - filename of model after tracking weight optimizations. Appends "_Final" to modelname
* **kinfile** - filename of IK results. Default is *"Visual3d_SIMM_input.mot"*
* **grffile** - filename of ground reaction forces. Default is *"Visual3d_SIMM_grf.mot"*
* **extloadsetup** - filename where external loads specifications will be written. Default "External_Loads_grf.xml"
* **actuatorfile** - filename to write reserver actuators. Default is "RRA_reserves.xml"
* **taskfile** - filename to write tracking tasks. Default is *"RRA_tasks.xml"*
* **rrasetupfile** - filename to initial RRA tool setup xml. Default is *"RRA_setup.xml"*
* **masssetupfile** - filename to RRA tool setup xml for mass iterations. Default is *"RRA_Setup_massItrs.xml"* 
* genericsetup - unused. Will be removed.

### Class: rraoptions
Only a constructor method exists for this class. The returned rraoptions object is used to store settings for the RRA tool and has the following properties.
* **starttime** - time to start simulation (default is 0). If not manually changed, the start time will be set to match the first frame of motion data.
* **endtime** - time to end the simulation (default is 1). If not manually changed, the end time will be set to match the last frame of motion data.
* **bForceset** - True/False whether to replace the model force set or not
* **bAdjustCOM** - True/False whether to adjust a body center of mass
* **comBody** - string name of body to adjust (default spec is torso)
* **trialpath** - system path to trial folder (passed from rrasetup constructor) 
* **modelname** - filename of model (passed from rrasetup constructor)
* **actuatorfile** - filename for reserve actuators (passed from rrasetup constructor)
* **extloadsetup** - filename for external loads specifications (passed from rrasetup constructor)
* **kinfile** - motion file (passed from rrasetup constructor)
* **taskfile** - tracking tasks filename
* **resultspath** - system path to output folder
* **outname** - output model name
* **rrasetupfile** - full path name to the RRA tool setup xml file
