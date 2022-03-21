# rra-optimization
An evolutionary algorithm-based optimization for tracking weights in the OpenSim Residual Reduction Algorithm (RRA).

## Contents
**main code**
* +rraTools</span> - This folder contains the MATLAB classes used in the optimization scheme. The folder containing "+rraTools" needs to be in the MATLAB path. _Do not add "+rraTools" directly to the path!_ These classes are accessible to MATLAB after calling  "import rraTools.* ". 

* +rraTools\rrasetup.</span>m - Class containing the main attributes and methods required to perform the tracking weight optimization.
* +rraTools\rrafiles.</span>m - Helper class with input and output filename specifications used by the RRA scheme.
* +rraTools\rraoptions.</span>m - Helper class with attributes used to assign values to the required options in the OpenSim RRA tool.
* +rraTools\extloadoptions.</span>m - Helper class with attributes used to specify ground reaction column identifiers and body name on which to apply force.

To include this namespace in your code use:
```{MATLAB}
import rraTools.*
```

**example scripts**
* example_defaultTWSA.m - demonstrates how to set up the class and run methods using default parameters.

* example_customTWSA.m - Sets up the class and runs TWSA using customized cost function weights and normalization terms.

* example_specifyTrackingWeights.m - This example demonstrates how to specify unique tracking weights for the initialRRA() and mass iterations.

* TWSA_paper_setup.m - This will run the TWSA with identical parameters as were used in [the published paper](https://www.biorxiv.org/content/10.1101/2021.10.06.463431v1.full.pdf).


**housekeeping**

required MATLAB libraries:

* opensim - [installation instructions for OpenSim MATLAB libraries](https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+with+Matlab)



### Class: rrasetup 
Calling the constructor **"obj = rrasetup(trialpath, participant, condition, mass)"** returns an object initialized with file tags and folder paths specific to a single motion trial/simulation. This object posesses several methods to perform residual reduction steps as needed.
#### Properties:
**participant** - participant label (e.g. subject01, S001, etc)
**condition** - optional specification if your scaled models are saved as "participant_condition.osim" (e.g. subject01_run20002.osim)
**mass** - participant mass
**trialpath** - system path to the trial folder containing the scaled model, motion, and grf files.
**modelname** - filename of participant scaled model. Uses input arguments to construct. *(participant)_(condition).osim*
**modfullfile** - full system path to model file, constructed as *trialpath\modelname*
**fileset** - instance of subclass "rrafiles"
**toolsettings** - instance of subclass "rraoptions"
**extloadsettings** - instance of subclass "extloadoptions"
**initDelMass** - mass change from first iteration of RRA
**totalDelMass** - total mass change from RRA mass iterations
**numMassItrs** - number of RRA iterations until mass changes converged

#### Methods: 
1. **"obj = rrasetup(trialpath, participant, condition, mass)"**
2. **initialRRA()** - run RRA on scaled model, generate mass adjusted model
3. **runMassItrsRRA()** - run RRA iterations to continue mass adjustments
4. **optimizeTrackingWeights()** - perform tracking weight optimization
* **writeRRATool()** - write out RRA setup xml file based on options currently specified in obj.toolsettings
* **adjMass()** - called by initialRRA() and runMassItrsRRA(). Reads and applies mass change recommendations from log file.
* **writeReservesFile()** - write reserve actuators force set as xml
* **writeTasksFile()** - write out tracking tasks as xml
* **writeExtLoads()** - write out external loads specification file based on options currently specified in obj.extloadsettings
* **readPeakExtForce()** - caculate the max net ground reaction force
* Additional internal helpers and nested classes are defined, but not described here.

### SubClass: rrafiles
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

Based on your specific needs, it may be helpful to modify the default assignments to "kinfile" and "grffile" by editing "rrafiles.m" after you download. This works well if you use a generic filename for all study participants and thus do not need to update the property after instantiating the tool. If you use participant and condition specific file names like "subject01_run20002_Trial_1_IK", it is best to update these properites after initializing the "rrasetup" class instance as is done in the example file provided ("runOptimizerHamner_Test.m" lines 22-24).
### SubClass: rraoptions
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

Depending on your OpenSim model, you may need to update the "comBody" property or edit the default assignment. For example, some models use "Torso" instead of "torso", or you may wish to adjust the center of mass of the pelvis instead. Edit the assigned "rraoptions.m" as needed.
### SubClass: extloadoptions
Only a constructor method exists for this class.
#### Properties
* **forceName_left** - name of external load created for left foot
* **forceName_right** - name of external load created for right foot
* **appliedBody_left** - name of the body on which the left force is applied (usually calcn_l)
* **appliedBody_right** - name of the body on which the right force is applied (usually calcn_r)
* **forceID_left** - column identifier corresponding to left force in the grf.mot file
* **pointID_left** - column identifier corresponding to left center of pressure in the grf.mot file
* **torqueID_left** - column identifier corresponding to left freemoment in the grf.mot file
* **forceID_right** - column identifier corresponding to right force in the grf.mot file
* **pointID_right** - column identifier corresponding to right center of pressure in the grf.mot file
* **torqueID_right** - column identifier corresponding to right  freemoment in the grf.mot file
* **expressedInBody** - name of the body in which the center of pressure and force data are expressed (usually ground)

You may find it useful to modify the default assignments in this file. For example, different versions of .mot files label the freemoment as "ground_torque" and "l_ground_torque", but others may use the labels "ground_moment_1" and "ground_moment_2". Edit "extloadoptions.m" as needed.