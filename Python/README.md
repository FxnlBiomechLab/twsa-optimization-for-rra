# rra-optimization
An evolutionary algorithm-based optimization for tracking weights in the OpenSim Residual Reduction Algorithm (RRA).

## Contents
**main code**
* reduceresiduals.py - class and methods definitions to perform RRA steps including the tracking weight optimizaiton scheme. Descriptions of classes and methods are below. To include this namespace in your code use:
```{python}
import reduceresiduals
```

**example scripts**
* example_defaultsTWSA.py - Python example script (Jupyter notebook format) demonstrating basic useage of the classes and methods.

* example_customTWSA.py - This example demonstrates how to specify custom weights and normalization factors for the TWSA.

* example_specifyTrackingWeights.py - This example demonstrates how to specify unique tracking weights for the initialRRA() and mass iterations.

**housekeeping**
* \_\_init__.py - folders containing this file are searchable by the Python environment. This makes classes contained in the same folder available via **import** commands. 

required python libraries:

* opensim - [installation instructions for OpenSim python libraries](https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+in+Python)
* re
* pandas
* os 
* math
* numpy
* pickle 
* subprocess


### Class: rrasetup 
#### Properties
* **participant**
* **condition**
* **trialpath**
* **condition**
* **modelname**
* **modfullpath**
* **fileset** -- Instance of class: rrafiles
* **toolsettings** -- Instance of class: rraoptions                           
* **initMassChange**
* **totalMassChange**
* **numMassItrs**

#### Methods: 
1. **rrasetup(trialpath, participant, condition)** -- constructor
2. **initialRRA()** 
3. **runMassItrsRRA()** 
4. **optimizeTrackingWeights()**
* **writeRRATool()** 
* **adjMass()** 
* **createReservesFile()** 
* **createTasksFile()**
* **createExtLoads()** 
* **readPeakExtForce**
* Additional internal helpers and nested classes are defined, but not described here.

### Class: rrafiles
Only a constructor method exists for this class. The returned rrafiles object has the following properties.
#### Properties: 
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


### Class: rraoptions
Only a constructor method exists for this class. The returned rraoptions object is used to store settings for the RRA tool and has the following properties.
#### Properties: 
* **starttime** - default 0, is set to the first frame in the motion file unless updated before calling initialRRA()
* **endtime** - default 0, is set to the last frame in the motion file unless updated before calling initialRRA()
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
* **LPhz** - lowpass filter frequency on the kinematic data. default is -1, which is no filtering
* **rrasetupfile** - full path name to the RRA tool setup xml file


### Class: extloadoptions
Only the constructor exists.
#### Properties: 
* **forceName_left** - name of OpenSim external force for left GRF, default "ExternalForce_2"
* **forceName_right** - name of OpenSim external force for right GRF, default "ExternalForce_1"
* **appliedBody_left** - body in OpenSim model on which left GRF is applied, default "calcn_l"
* **appliedBody_right** - body in OpenSim model on which right GRF is applied default "calcn_r"
* **forceID_left** - header specification for left forces, default "l_ground_force_v"
* **pointID_left** -  header specification for left center of pressure, default "l_ground_force_p"
* **torqueID_left** -  header specification for left freemoment, default "l_ground_torque"
* **forceID_right** -  header specification for right forces, default "ground_force_v"
* **pointID_right** -  header specification for right center of pressure, default "ground_force_p"
* **torqueID_right** -  header specification for right freemoment, default "ground_torque"
* **expressedInBody** -  name of OpenSim body in which frame the forces are expressed in, default "ground"