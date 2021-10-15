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
#### Properties:
**participant**
**condition**
**mass**
**trialpath**
**modelname**
**modfullfile**
**fileset**
**toolsettings**
**initDelMass**
**totalDelMass**
**numMassItrs**
#### Methods: 
1. **"obj = rrasetup(trialpath, participant, condition, mass)"**
2. **initialRRA()**
3. **runMassItrsRRA()** 
4. **optimizeTrackingWeights()** 
* **writeRRATool()** 
* **adjMass()** 
* **writeReservesFile()** 
* **writeTasksFile()**
* **writeExtLoads()**

* Additional internal helpers and nested classes are defined, but not described here.

### Class: rrafiles
Only a constructor method exists for this class.
#### Properties
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
Only a constructor method exists for this class. 
#### Properties
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
