# includes
import re # regular expression support
import pandas
import opensim as osim
import os # file path and system command control
import math
import numpy as np
import pickle # needed to save/load opt results
import subprocess # copy/rename/move files
#

# begin class def
class rrasetup: # constructor method
    def __init__(self, trialpath, participant, condition, mass):
        """
        Constructor method for class rrasetup:
            Returns an object initialized with file tags and folder paths 
            specific to a single motion trial/simulation. This object posesses 
            several methods to perform residual reduction steps as needed.  
        """
        
        # holdover properties from prior calibration tool implementation, these are not needed for the rra aspect
        #self.basefolder = basefolder
        #self.slope = slope
        #self.trialnum = trialnum
        #self.trialpath = os.path.join(self.basefolder,self.participant,self.condition,self.slope,'Trial_' + str(self.trialnum)) # full system path to trial folder
        #self.setupsfolder = setupsfolder #"C:\Users\Jordan\Documents\PhD\Models\Setups"
        
        # class properties
        self.mass = mass
        self.participant = participant
        self.condition = condition
        self.trialpath = trialpath
        if self.condition:
            self.modelname = ''.join(self.participant + '_' + self.condition + '.osim')
        elif not self.condition:
            self.modelname = ''.join(self.participant + '.osim')
        
        self.modfullpath = os.path.join(self.trialpath,self.modelname)
        self.fileset = rrafiles(self.trialpath, self.participant, self.condition)
        self.toolsettings = rraoptions(0,1,True,True,"torso",self.trialpath,self.modelname,
                                        self.fileset.actuatorfile,self.fileset.extloadsetup,
                                        self.fileset.kinfile,self.fileset.taskfile,
                                        self.fileset.resultspath,self.fileset.outname,self.fileset.rrasetupfile) 
        self.initMassChange = 0
        self.totalMassChange = 0
        self.numMassItrs = 0
    
    def writeRRATool(self):
        """
        Short helper function:
            Configures and prints the xml setup file for RRA using settings 
            specified within the rrasetup class properties.
        """
        # create an RRA tool and set the initial settings
        rraTool = osim.RRATool()
        rraTool.setName("RRA")
        rraTool.setInitialTime(self.toolsettings.starttime)
        rraTool.setFinalTime(self.toolsettings.endtime)
        rraTool.setStartTime(self.toolsettings.starttime)
        rraTool.setReplaceForceSet(self.toolsettings.bForceset)
        rraTool.setAdjustCOMToReduceResiduals(self.toolsettings.bAdjustCOM)
        rraTool.setAdjustedCOMBody(self.toolsettings.comBody)
        rraTool.setModelFilename(os.path.join(self.toolsettings.trialpath,self.toolsettings.modelname))
        forceStr = osim.ArrayStr()
        forceStr.append(os.path.join(self.toolsettings.trialpath,self.toolsettings.actuatorfile))
        rraTool.setForceSetFiles(forceStr)
        rraTool.setExternalLoadsFileName(os.path.join(self.toolsettings.trialpath,self.toolsettings.extloadsetup))
        rraTool.setDesiredKinematicsFileName(os.path.join(self.toolsettings.trialpath,self.toolsettings.kinfile))
        rraTool.setTaskSetFileName(os.path.join(self.toolsettings.trialpath,self.toolsettings.taskfile))
        rraTool.setOutputModelFileName(os.path.join(self.toolsettings.trialpath,self.toolsettings.outname))
        rraTool.setResultsDir(self.toolsettings.resultspath)
        btoolprinted = rraTool.printToXML(os.path.join(self.toolsettings.trialpath,self.toolsettings.rrasetupfile))
        return(btoolprinted) 

    def initialRRA(self, createTasks = True, createReserves = True, createExtLoads = True):
        """
        Performs an initial RRA iteration using a scaled, non-mass adjusted model.
            Optional keyword arguments: 
                createTasks -- boolean with default to true. Calls createTasks method unless set to false.
                createReserves -- boolean with default to true. Calls createReseves method unless set to false. 
                createExtLoads -- boolean with default to true. Calls createExtLoads method unless set to false. 
        """
        ikdata=osim.Storage(os.path.join(self.fileset.trialpath,self.fileset.kinfile))
        timedata = osim.ArrayDouble()
        ikdata.getTimeColumn(timedata)
        self.toolsettings.starttime = timedata.get(0)
        self.toolsettings.endtime = timedata.getLast()

        bToolPrinted = self.writeRRATool()

        if createTasks: # boolean input to the method
            self.createTasksFile()
        if createExtLoads: # boolean input to the method
            self.createExtLoads()
        if createReserves: # boolean input to the method
            self.createReservesFile()

        if not(os.path.isdir(self.fileset.resultspath)):
            os.mkdir(self.fileset.resultspath)

        # change directory so err and out files are written into the results folder
        mydir = os.getcwd()
        os.chdir(self.fileset.resultspath)
        # run the rra tool
        command_rra = 'opensim-cmd run-tool ' + os.path.join(self.fileset.trialpath,self.fileset.rrasetupfile)
        os.system(command_rra)
        os.chdir(mydir) # change back to initial directory

        self.initMassChange = self.adjMass()
        self.totalMassChange = self.initMassChange
        self.numMassItrs = self.numMassItrs + 1
        return
        
    def runMassItrsRRA(self):
        """
        Performs a series of RRA iterations with mass adjustments.
            Use after the initial RRA iteration to perform model mass adjustments 
            until the detected mass change is less than 0.001 kg. 
            Maximum number of iterations is 10.
        """
        # FUNCTION RUNMASSITRSRRA() performs up to 10 iterations of RRA
        # until the recomended mass change is less than the threshold
        # 0.001. Note: call the method as "obj = self.runMassItersRRA()"
        # to track the total mass change and number of iterations.
        
        mass_change = 100 # initialize mass change variable to high value so loop will run 
        
        # create the tool
        ikdata = osim.Storage(os.path.join(self.fileset.trialpath,self.fileset.kinfile))
        timedata = osim.ArrayDouble()
        ikdata.getTimeColumn(timedata)
        self.toolsettings.starttime = timedata.get(0)
        self.toolsettings.endtime = timedata.getLast()
        self.toolsettings.comBody = "torso"
        self.toolsettings.rrasetupfile = self.fileset.masssetupfile
        self.toolsettings.modelname = self.fileset.adjname
        self.toolsettings.resultspath = self.fileset.adjresultspath
        
        # create the results path
        if not(os.path.isdir(self.toolsettings.resultspath)):
            os.mkdir(self.toolsettings.resultspath)
            
        btoolprinted = self.writeRRATool()
        # do until mass adjust < tolerance (up to 10 iterations)
        for iternum in range(1,10):
            if abs(mass_change) < 0.001:
                break

            # move into the results directory to run the RRA tool
            mydir = os.getcwd()
            os.chdir(self.toolsettings.resultspath)
            # string to send to the command line
            command_rra = 'opensim-cmd run-tool ' + os.path.join(self.fileset.trialpath,self.fileset.masssetupfile)
            os.system(command_rra)
            # change back to original directory
            os.chdir(mydir)
            # adjust model mass
            mass_change = self.adjMass()
            # count iters
            self.totalMassChange = self.totalMassChange + mass_change
            self.numMassItrs = self.numMassItrs + 1


    def adjMass(self):
        """
        Edits the model to make recommended mass adjustments.
            This helper funciton is called by initialRRA and runMassItrsRRA. 
            Reads the recommended mass adjustments from the RRA log file, 
            and makes mass and COM edits to the model.
        """
        #import re
        # Read recommended mass adjustment
        logfile_a = os.path.join(self.toolsettings.resultspath,'out.log') # v3.x - v4.1
        logfile_b = os.path.join(self.toolsettings.resultspath,'opensim.log') # v4.2

        if os.path.is_file(logfile_a):
            logfile = logfile_a
        elif os.path.is_file(logfile_b):
            logfile = logfile_b
        else:
            print('No matching log file found!')

        
        regexp = re.compile(r"\*  Total mass change: ?([0-9.]+)?") # line to search for in file
        
        with open(logfile) as f: 
            lines = f.readlines()
            for l in range(0,len(lines)-1):
                if regexp.match(lines[l]) != None: # find the right line
                    value = re.findall(r"[-+]?\d*\.\d+|\d+", lines[l]) # extract the float value from appropriate line
                    mass_change = float(value[0]) # should be only one entry in the array
                    print(mass_change)

        #Initialize an OpenSim model from the RRA output
        model = osim.Model(os.path.join(self.toolsettings.trialpath,self.toolsettings.outname))
        state = model.initSystem()
        oldMass = model.getTotalMass(state)
        # update the target mass
        newMass = oldMass + mass_change
        # get the scale set 
        scaleset = osim.ScaleSet()
        # scale the model to the new mass, preserving segment lengths and mass distribution 
        res = model.scale(state,scaleset,True,newMass) # different order from 3.3 API
        
        # if res==0:
            # need to add some error handling. User defined exceptions probably best 
            #error('Model mass scaling failed.')
        
        #Print the adjusted model
        model.printToXML(os.path.join(self.trialpath,self.fileset.adjname))
        return(mass_change)
            
    def createReservesFile(self, skip_coords = ["bp_tx","bp_ty"], ReserveForce = 1600, ResidualForce = 100):
        """
        Configures and prints the reserve actuators force set to xml file.
        Optional keyword arguments: 
            skip_coords -- a list of strings specifying any coordinates to not actuate (will be given an optimal force of 1)
                           These will typically be untracked or free coordinates.
            ReserveForce -- a numeric input to specify the optimal force for all other reserves (default is 1600)
            ResidualForce -- a numeric input to specify the optimal force for residual actuators (default is 100)
        """
        mod = osim.Model(self.modfullpath)
        s = mod.initSystem()
        # create set of actuators
        reserve_set = osim.ForceSet()
        coords = mod.getCoordinateSet()
        numc = coords.getSize()
        reserve_names = [] # i don't think this is used anymore
        #r = 0
        for c in range(0,numc-1):
            cname = coords.get(c).getName()
            if not(coords.get(c).isConstrained(s)):
                #print(cname)
                if "pelvis" in cname:
                    cm = osim.Vec3()
                    cm = mod.getBodySet().get("pelvis").getMassCenter()
                    if "tilt" in cname:
                        curAct = osim.CoordinateActuator()
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_coordinate(cname)
                        curAct.setName("MZ")
                    elif "list" in cname:
                        curAct = osim.CoordinateActuator()
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_coordinate(cname)
                        curAct.setName("MX")
                    elif "rotation" in cname:
                        curAct = osim.CoordinateActuator()
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_coordinate(cname)
                        curAct.setName("MY")
                    elif "tx" in cname:
                        curAct = osim.PointActuator()
                        curAct.set_body("pelvis")
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_direction(osim.Vec3(1,0,0))
                        curAct.set_point(cm)
                        curAct.set_point_is_global(False)
                        curAct.set_force_is_global(True)
                        curAct.setName("FX")
                    elif "ty" in cname:
                        curAct = osim.PointActuator()
                        curAct.set_body("pelvis")
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_direction(osim.Vec3(0,1,0))
                        curAct.set_point(cm)
                        curAct.set_point_is_global(False)
                        curAct.set_force_is_global(True)
                        curAct.setName("FY")
                    elif "tz" in cname:
                        curAct = osim.PointActuator()
                        curAct.set_body("pelvis")
                        curAct.setOptimalForce(ResidualForce)
                        curAct.set_direction(osim.Vec3(0,0,1))
                        curAct.set_point(cm)
                        curAct.set_point_is_global(False)
                        curAct.set_force_is_global(True)
                        curAct.setName("FZ")   
                else:
                    curAct = osim.CoordinateActuator()
                    curAct.setName(cname)
                    curAct.set_coordinate(cname)
                    if cname in skip_coords:
                        curAct.setOptimalForce(1)
                    else:
                        curAct.setOptimalForce(ReserveForce)
                curAct.setMaxControl(1000)
                curAct.setMinControl(-1000)

                # remember names that are already added
                reserve_names.append(cname)
                # add actuator to reserve set
                reserve_set.cloneAndAppend(curAct)
                
        # add passive force elements. This will add certain passive force elements defined in the model to the reserve set (CoordinateLimitForce, ExpressionBasedBushing). Actuators and other bushings are ignored.  
        mNames = osim.ArrayStr()
        fNames = osim.ArrayStr()
        modForce = mod.getForceSet()
        modForce.getNames(fNames)
        modAct = modForce.getActuators()
        modAct.getNames(mNames)

        for f in range(0,modForce.getSize()):
            loc = mNames.rfindIndex(fNames.get(f))
            if loc == -1:
                #print(fNames.get(f), " not found in actuators")
                if ( "BushingForce" in str(modForce.get(f).getConcreteClassName()) ):
                     if ("ExpressionBased" in str(modForce.get(f).getConcreteClassName()) ): 
                        reserve_set.cloneAndAppend(modForce.get(f))
                        #print("adding to RRA reserve set")
                else:
                    reserve_set.cloneAndAppend(modForce.get(f))
                
        success = reserve_set.printToXML(os.path.join(self.fileset.trialpath,self.fileset.actuatorfile))
        return(success)

    def createTasksFile(self, skip_coords = ["bp_tx","bp_ty"], Kp = 1600, UniformWeights = True, UserWeights = []):
        """
        Configures and prints the tracking task set to xml file.
        Optional keyword arguments: 
            skip_coords -- list of strings specifying coordinates that will not be tracked (which are otherwise unconstrained)
            Kp -- numeric value for proportional gain of the tracking weight controller (default = 1600) 
            UniformWeights -- boolean to either use equal weights for all tasks (default = True), 
                              or to use predefined, stronger weights for certain coordinates (False). 
            (Not used) UserWeights -- future incorporation will allow use to specify any weights using name value pairs.
        """    
        Kv = 2*math.sqrt(Kp) # enforce critical damping
        
        mod = osim.Model(self.modfullpath)
        s = mod.initSystem()
        
        #print("creating task set")
        task_set = osim.CMC_TaskSet()
        coords = mod.getCoordinateSet()

        for c in range(0,coords.getSize()-1):
            if not(coords.get(c).isConstrained(s)):
                cname = coords.get(c).getName()
                if not(cname in skip_coords):
                    curTask = osim.CMC_Joint(cname)
                    curTask.setName(cname)
                    curTask.setKP(Kp)
                    curTask.setKV(Kv)
                    curTask.setActive(True,False,False)
                    curTask.setOn(True)

                    if UniformWeights:
                        curTask.setWeight(1,1,1)
                    else:
                        # add statement to match userdefined weights (in MATLAB: contains(userNames, cname))
                        if "pelvis" in cname:
                            curTask.setWeight(1,1,1)
                        elif cname in ['flex_extension','axial_rotation','lat_bending','L5_S1_FE','L5_S1_LB','L5_S1_AR']:
                            curTask.setWeight(5,1,1)
                        elif "ankle" in cname:
                            curTask.setWeight(20,1,1)
                        elif "knee" in cname:
                            curTask.setWeight(10,1,1)
                        elif "hip" in cname:
                            curTask.setWeight(5,1,1)
                        else:
                            curTask.setWeight(1,1,1)

                    task_set.cloneAndAppend(curTask)    

        success = task_set.printToXML(os.path.join(self.trialpath, self.fileset.taskfile))
        return(success)

    def createExtLoads(self):
        """
        Configures and prints the external loads specification xml file.
        """
        extLoads = osim.ExternalLoads()
        exf = osim.ExternalForce()
        exfl = osim.ExternalForce()
        
        exf.setName('ExternalForce_1')
        exf.set_appliesForce(True)
        exf.setAppliedToBodyName('calcn_r')
        exf.setForceExpressedInBodyName('ground')
        exf.setPointExpressedInBodyName('ground')
        exf.setForceIdentifier ('ground_force_v')
        exf.setPointIdentifier ('ground_force_p')
        exf.setTorqueIdentifier('ground_torque')
        exf.set_data_source_name(os.path.join(self.trialpath, self.fileset.grffile))
        extLoads.cloneAndAppend(exf)
        
        
        exfl.setName('ExternalForce_2')
        exfl.set_appliesForce(True)
        exfl.setAppliedToBodyName('calcn_l')
        exfl.setForceExpressedInBodyName('ground')
        exfl.setPointExpressedInBodyName('ground')
        exfl.setForceIdentifier ('l_ground_force_v')
        exfl.setPointIdentifier ('l_ground_force_p')
        exfl.setTorqueIdentifier('l_ground_torque')
        exfl.set_data_source_name(os.path.join(self.trialpath, self.fileset.grffile))
        extLoads.cloneAndAppend(exfl)
        
        extLoads.setDataFileName(os.path.join(self.trialpath, self.fileset.grffile))
        #extLoads.setExternalLoadsModelKinematicsFileName(os.path.join(self.trialpath, self.fileset.kinfile))
        b = extLoads.printToXML(os.path.join(self.trialpath, self.fileset.extloadsetup))
        return(b)

    def optimizeTrackingWeights(self,mass = 75, min_itrs = 25, max_itrs = 75,fcn_threshold = 2, wRes = 2, wErr = 1, pRes = 3, pErr = 3):
        """
        Performs the tracking weight optimization algorithm using the mass adjusted model. 
        Optional keyword arguments: 
            min_itrs -- integer to specify a minimum number of iterations to use (default = 25)
            max_itrs -- integer to specify a maximum number of iterations (default = 75)
            fcn_threshold -- numeric input to specify target cost function value for good enough convergence 
            wRes -- numeric multiplier for the residual cost term (default = 2) 
            wErr -- numeric multiplier for the tracking errors cost term (default = 1)
            pRes -- numeric polynomial power for the residual cost term  
            pErr -- polynomial power for the tracking errors cost term

        Additional hidden methods contained are helper functions to this main 
        tracking weight optimization method.   
        """
        #**************************************************************************
        # OPTIMIZE RESIDUAL FORCES AND TRACKING ERRORS
        #**************************************************************************
        # RRA Optimization scheme used to reduce residuals and kinematic errors
        #   through adjusted task weights and actuator opt forces
        # INPUTS: name - participant label (used in file structure) 
        #         trial - movement trial label (used in file structure)
        #         OPTFILES - global variable loaded within function to set file
        #             paths for all relevant supporting files including base path for
        #             files, RRA file paths, optimization iteration structure
        #
        #   Developed by Nathan Pickle October 12, 2016 at Colorado School of Mines
        #   Code adapted by Amy Hegarty Febuary 14, 2017
        #   Further modifications by Jordan Sturdy March 4, 2021
        


        #import pickle # needed to save/load opt results
        #import subprocess

        #time program duration...
        #tic %start program timer
        if not(os.path.isdir(self.fileset.optpath)):
            os.mkdir(self.fileset.optpath)
        if not(os.path.isdir(os.path.join(self.fileset.optpath,"Tasks"))):
            os.mkdir(os.path.join(self.fileset.optpath,"Tasks"))
        if not(os.path.isdir(os.path.join(self.fileset.optpath,"Results"))):
            os.mkdir(os.path.join(self.fileset.optpath,"Results"))

        newtaskSetFilename = os.path.join(self.fileset.optpath,'Tasks','optItr_' + str(0) + '_Tasks.xml')
        
        # copy needed files into optimization folder
        src1 = os.path.join(self.fileset.trialpath,self.fileset.taskfile)
        dst1 = newtaskSetFilename
        cp1cmd = 'copy "%s" "%s"' % (src1,dst1)
        status1 = subprocess.call(cp1cmd, shell = True)

        src2 = os.path.join(self.fileset.trialpath,self.fileset.actuatorfile)
        dst2 = os.path.join(self.fileset.optpath,self.fileset.actuatorfile)
        cp2cmd = 'copy "%s" "%s"' % (src2,dst2)
        status2 = subprocess.call(cp2cmd, shell = True)

        src3 = os.path.join(self.fileset.trialpath,self.fileset.extloadsetup)
        dst3 = os.path.join(self.fileset.optpath,self.fileset.extloadsetup)
        cp3cmd = 'copy "%s" "%s"' % (src3,dst3)
        status3 = subprocess.call(cp3cmd, shell = True)

        src4 = os.path.join(self.fileset.trialpath,self.fileset.kinfile)
        dst4 = os.path.join(self.fileset.optpath,self.fileset.kinfile)
        cp4cmd = 'copy "%s" "%s"' % (src4,dst4)
        status4 = subprocess.call(cp4cmd, shell = True)

        src5 = os.path.join(self.fileset.trialpath,self.fileset.grffile)
        dst5 = os.path.join(self.fileset.optpath,self.fileset.grffile)
        cp5cmd = 'copy "%s" "%s"' % (src5,dst5)
        status5 = subprocess.call(cp5cmd, shell = True)

        #Define initial tracking weights


        Sresults_file = os.path.join(self.fileset.optpath,'opt_results.optStruct')
        if os.path.isfile(Sresults_file):
            with open(Sresults_file,'rb') as input_file:
                S = pickle.load(input_file)
            #itr = S.itr
        else:
            S = self._optStruct() # initialize data structure

            #Set objective function parameters (altering paramters will set higher or
                #lower precedence on residuals, and errors

            S.wRes = wRes #  multiplication factor
            S.wErr = wErr
            S.pRes = pRes #  exponential factor
            S.pErr = pErr

            # load default task values 
            taskFileName = os.path.join(self.fileset.trialpath,self.fileset.taskfile)
            S.trackingWeights = self.__readTrackingWeights__(taskFileName)
            print(S.trackingWeights.values)
            S.xnew = S.trackingWeights
            S.fnew = 10000

            #Set iteration limit

            S.thresh = fcn_threshold
            S.i_min = min_itrs
            S.i_max = max_itrs
            S.itr = 0

            #Run RRA with default values
            #load RRATool to assess trial variables and update RRA tool for opt itrs.
            rratool = osim.RRATool(os.path.join(self.fileset.trialpath,self.fileset.rrasetupfile))

            #set RRA parameters (tool name, model files, task list name, results dir)
            rratool.setName('optItr_' + str(S.itr))
            rratool.setModelFilename(os.path.join(self.fileset.trialpath,self.fileset.adjname)) 
            rratool.setOutputModelFileName(os.path.join(self.fileset.optpath,self.fileset.adjname))
            rratool.setResultsDir(os.path.join(self.fileset.optpath,'Results'))
            rratool.setTaskSetFileName(newtaskSetFilename)
            rratool.setMaximumNumberOfSteps(20000)
            rratool.setAdjustCOMToReduceResiduals(False)
            # print rra setup file 
            rraSetupFile = os.path.join(self.fileset.optpath,'optItr_' + str(S.itr) + '_Setup.xml')
            rratool.printToXML(rraSetupFile)


            #Run RRA tool from command line 
            mydir = os.getcwd()
            os.chdir(os.path.join(self.fileset.optpath,'Results'))
            
            # string to send to the command line
            command_rra = 'opensim-cmd run-tool ' + rraSetupFile
            os.system(command_rra)
            os.chdir(mydir)
            print('initial opt run completed')
            
            # calculate objective function values from base rra trial
            mod = osim.Model(os.path.join(self.fileset.trialpath,self.fileset.adjname))
            state = mod.initSystem()
            mass = mod.getTotalMass(state)
            print('total model mass: ' + str(mass))
            S = self.__calculateObjectiveFunction__(S,mass)
            S.xcurrent = S.xnew

            #Store default results
            S.ObjFuncValues = np.append(S.ObjFuncValues,S.fnew)
            S.fcurrent = S.fnew
            S.TestedSolutions[0] = np.array(S.trackingWeights.values)

        #loop through rra iterations
        while S.itr <= S.i_max:
            if S.itr >= S.i_min:
                if min(S.ObjFuncValues) < S.thresh:
                    break

            # exectute task optimization famework (preturb task values, run rra
            #   iteration, calculate objective function new value
            print('entering iteration loop...')
            S = self.__executeRRAOptLoop__(S,mass)


        #Run Final RRA Solution
        print('solution found, or max iterations reached')
        # Find the best solution and re-run it to make sure our results are current
        objVals = np.array(S.ObjFuncValues)

        for i in range(0,len(objVals)):
            if objVals[i] == objVals.min():
                idx = i
                break

        bestSoln = S.TestedSolutions[idx]

        # Assign the tracking weight values
        S.xbest = S.xnew #Initialize
        for i_coord in range(0,len(S.xnew.names)-1):
            S.xbest.values[i_coord] = bestSoln[i_coord]
        
        # Create setup file and task set with final tracking weights
        S.trackingWeights = S.xbest
        taskSetFilenametemplate = os.path.join(self.fileset.trialpath,'RRA_Tasks.xml')
        taskSetFilenamenew = os.path.join(self.fileset.optpath,'Tasks','RRA_Final_Tasks.xml')
        newtaskSetFilename = self.__writeTrackingWeights__(taskSetFilenametemplate,taskSetFilenamenew,S.xbest)

        # Run RRA with current iteration values
        #load RRATool to assess trial variables and update RRA tool for opt itrs.
        rratool = osim.RRATool(os.path.join(self.fileset.trialpath,self.fileset.rrasetupfile))

        # update rra steup tool parameters
        rratool.setName('RRA')
        rratool.setModelFilename(os.path.join(self.fileset.trialpath,self.fileset.adjname))
        rratool.setOutputModelFileName(os.path.join(self.fileset.trialpath,self.fileset.optname))
        rratool.setResultsDir(self.fileset.finalpath)
        rratool.setTaskSetFileName(newtaskSetFilename)
        rratool.setMaximumNumberOfSteps(20000)
        rraSetupFile = os.path.join(self.fileset.optpath,'RRA_Final_Setup.xml')
        rratool.printToXML(rraSetupFile)


        #Run RRA tool from command line inside matlab
        if not(os.path.isdir(self.fileset.finalpath)):
            os.mkdir(self.fileset.finalpath)

        mydir = os.getcwd()
        os.chdir(self.fileset.finalpath)
        
        command_rra = 'opensim-cmd run-tool ' + rraSetupFile
        os.system(command_rra)

        os.chdir(mydir)


        
    def __readTrackingWeights__(self,taskSetFilename): 
        print('reading tracking weights')
        #Default normalization factors
        rmsNormFactor_trans = 0.02
        rmsNormFactor_rot = 2*(math.pi/180)

        #Grab the xml document that defines the tracking weights
        RRATask = osim.CMC_TaskSet(taskSetFilename)

        num = RRATask.getSize()

        print(num)
        trackingWeights = self._weightStruct()
        #Parse tracking weights into structure 
        for i_weight in range(0,num):

            currWeightName = str(RRATask.get(i_weight).getName())
            print(currWeightName)

            currWeightValue = RRATask.get(i_weight).getWeight(0)

            trackingWeights.names.append(currWeightName) 
            trackingWeights.values.append(currWeightValue) 
            trackingWeights.rmsErr.append(10000)
            if currWeightName in ['pelvis_tx','pelvis_ty','pelvis_tz']:
                trackingWeights.rmsNormFactor.append(rmsNormFactor_trans)
            else:
                trackingWeights.rmsNormFactor.append(rmsNormFactor_rot)
            
        
        return(trackingWeights)
    #readTrackingWeights function


    #**************************************************************************
    # Function: Write task Set file with defined list of task weights
    def __writeTrackingWeights__(self,taskSetFilenameOld,taskSetFilenameNew,trackingWeights):
        print('writing tracking weights')
        #Grab the xml document that defines the tracking weights
        RRATask = osim.CMC_TaskSet(taskSetFilenameOld)
        num = RRATask.getSize()

        #Parse tracking weights into structure 
        for i_weight in range(0,num-1):
            # assign task weight for each coordinate in optfunction
            coorname = str(RRATask.get(i_weight).getName())
            try:
                loc = trackingWeights.names.index(coorname)
                RRATask.get(i_weight).setWeight(trackingWeights.values[loc],1,1)
            except ValueError:
                break        

        #write xml file with xmlwrite and remove extra spaces in file
        RRATask.printToXML(taskSetFilenameNew)

        return(taskSetFilenameNew)
    #writeTrackingWeights function


        #**************************************************************************
        # Function: calculate objective function value for RRA iterations
    def __calculateObjectiveFunction__(self,S,mass):
        #The objective function value is returned in the field 'fnew' of the
        #structure S.
        #=========================================
        # Import the actuation forces and moments
        #=========================================

        # JS
        # normalization factors for the residuals, adapted from OpenSim
        # Guidelines. Assume peak force is ~1.3 body weights. Good assumption for walking, but could be improved to find peak grf value instead
        #import pandas
        #import re
        print('calculating objective function: iteration  ' + str(S.itr))
        forceNormF = 1.3*9.81*mass*0.05 # 5 percent body_weight * 1.3 (Osim Guidelines are < 5 percent max ext force)
        momentNormF = forceNormF/5 # 1 percent body_weight * 1.3 (Osim guidelines are < 1 percent COM height*max ext force)

        if S.itr == 0:
            filename = os.path.join(self.fileset.optpath,'Results','optItr_'+str(S.itr)+'_Actuation_force.sto')  
        else: 
            filename = os.path.join(self.fileset.optpath,'Results','optItr'+'_Actuation_force.sto')
        
        if os.path.isfile(filename): #if RRA runs to completion, calculate objective function value from itration 
            regexp = re.compile(r"endheader?") # find the header line in the data file
            with open(filename) as f: 
                lines = f.readlines()
                for l in range(0,len(lines)-1):
                    if regexp.match(lines[l]) != None: 
                        headerlines = l+1

            print('reading actuation file')
            residuals = pandas.read_csv(filename, sep = '\t', header = headerlines, skip_blank_lines=False)
            arrayMX = []; arrayMY = []; arrayMZ = []
            arrayFX = []; arrayFY = []; arrayFZ = []
            for idx in range(0,len(residuals)-1):
                arrayMX.append(residuals.MX[idx])
                arrayMY.append(residuals.MY[idx])
                arrayMZ.append(residuals.MZ[idx])
                arrayFX.append(residuals.FX[idx])
                arrayFY.append(residuals.FY[idx])
                arrayFZ.append(residuals.FZ[idx])

            rmsFX = np.sqrt(np.mean(np.array(arrayFX)**2))
            rmsFY = np.sqrt(np.mean(np.array(arrayFY)**2))
            rmsFZ = np.sqrt(np.mean(np.array(arrayFZ)**2))
            rmsMX = np.sqrt(np.mean(np.array(arrayMX)**2))
            rmsMY = np.sqrt(np.mean(np.array(arrayMY)**2))
            rmsMZ = np.sqrt(np.mean(np.array(arrayMZ)**2))

            nresiduals = 6

            # Sum of RMS forces, normalized to OpenSim guidelines
            sumRMSForces = (rmsFX/forceNormF)**S.pRes+(rmsFY/forceNormF)**S.pRes+(rmsFZ/forceNormF)**S.pRes
            # Sum of RMS moments, normalized to OpenSim guidelines
            sumRMSMoments = (rmsMX/momentNormF)**S.pRes+(rmsMY/momentNormF)**S.pRes+(rmsMZ/momentNormF)**S.pRes
            
            sumMaxForces = (max(abs(np.array(arrayFX)))/forceNormF)**S.pRes+(max(abs(np.array(arrayFY)))/forceNormF)**S.pRes+(max(abs(np.array(arrayFZ)))/forceNormF)**S.pRes

            # Total sum of RMS forces and moments
            sumRMSResiduals = sumRMSForces+sumRMSMoments
            
            # update results data
            S.sumRMSResiduals = np.append(S.sumRMSResiduals,sumRMSResiduals)
            S.sumRMSForces = np.append(S.sumRMSForces,sumRMSForces)
            S.sumRMSMoments = np.append(S.sumRMSMoments,sumRMSMoments)
            # sumRMSResiduals = sumMaxForces+sumRMSMoments

            #=========================================
            # Import the Errors
            #=========================================
            if S.itr == 0:            
                filename = os.path.join(self.fileset.optpath,'Results','optItr_'+str(S.itr)+'_pErr.sto')
            else:
                filename = os.path.join(self.fileset.optpath,'Results','optItr'+'_pErr.sto')

            print('reading errors file')
            regexp = re.compile(r"endheader?") # find the header line in the data file
            with open(filename) as f: 
                lines = f.readlines()
                for l in range(0,len(lines)-1):
                    if regexp.match(lines[l]) != None: 
                        headerlines = l+1

            trackingErr = pandas.read_csv(filename, sep = '\t', header = headerlines, skip_blank_lines = False)

            #rmsErr = zeros(size([S.xnew.value]))
            rmsErr = []
            for i_coord in range(1,len(S.xnew.names)): 

                my_err = trackingErr.loc[:,S.xnew.names[i_coord]]
                my_sqerr = my_err.pow(2,axis = 0)
                rms = np.sqrt(my_sqerr.mean(axis = 0))

                rmsErr.append((rms/S.xnew.rmsNormFactor[i_coord])**S.pErr)
                S.xnew.rmsErr[i_coord] = rms

            

            sumRMSErrors = sum(rmsErr)
            S.sumRMSErrors = np.append(S.sumRMSErrors,sumRMSErrors)
            

            # Output the Objective Function
            ncoords = len(S.xnew.names)

            ###########################################################################

            S.fnew = S.wRes*(1/nresiduals)*sumRMSResiduals + S.wErr*(1/ncoords)*sumRMSErrors
            print('new ojective value: ' + str(S.fnew))
            ###########################################################################
        else: #if RRA iteration do not run to completion set new opt funt value to inf
            S.fnew= math.inf
            S.sumRMSErrors = np.append(S.sumRMSErrors,math.inf)
            S.sumRMSForces = np.append(S.sumRMSForces,math.inf)
            S.sumRMSMoments = np.append(S.sumRMSMoments,math.inf)
            S.sumRMSResiduals = np.append(S.sumRMSResiduals,math.inf)
            for i_coord in range(0,len(S.xnew.names)-1):
                #Assign maximum value for rmserror used to generate next solution of task values
                S.xnew.rmsErr[i_coord] = math.inf
            
        return S
        #calculateObjectiveFunction function


        #**************************************************************************
        # Function: Run RRA iterations with course optimization for task weights
    def __RHCP_itr__(self,S,body_mass):
        print('RHCP_itr')
        from random import sample
        #=========================================
        # Generate New Set of Task values
        #=========================================
        #Randomly generate a new solution, but it must not be one that has been
        #previously tested
        xunique = False
        while xunique==False:
            print('perturbing weights')
            #TEST FEATURE
            #Bias the shift based on the tracking error
            print(len(S.xcurrent.names))
            print(S.xcurrent.names)
            for i_coord in range(0,len(S.xcurrent.names)-1):
                print(S.xcurrent.names[i_coord])
                if S.xcurrent.names[i_coord] in ['pelvis_tx','pelvis_ty','pelvis_tz']:
                    # bounds adjusted by JS to evaluate how much this
                    # influences resulting tracking error.
                    lb = 0.01
                    ub = 0.03
                else:
                    lb = 1*(math.pi/180)
                    ub = 3*(math.pi/180)
                
                print('lower: '+ str(lb) + ' upper: ' + str(ub))

                #Bias the tracking weight change
                if S.xcurrent.rmsErr[i_coord] < lb:
                    print('green')
                    #If we are in the green, tend to decrease the weight
                    #t = randsample([-1,-1,-1,0,1],1)
                    t = sample([-2,-1,-1,0,1],1) # JS
                elif S.xcurrent.rmsErr[i_coord] > ub:
                    print('red')
                    #If we are in the red, tend to increase the weight
                    #t = randsample([-1,0,1,1,1],1)
                    t = sample([-1,0,1,1,2],1) # JS
                else:
                    print('yellow')
                    #Otherwise, equal chances
                    #t = randsample([-1,0,1],1)
                    t = sample([-2,0,-1,0,1,0,2],1) # JS
                    
                print('resolution')
                #Use finer resolution as we get further along
                if S.itr<=math.floor(S.i_max/2):
                    base = 1.5
                elif S.itr>math.floor(S.i_max/2) and S.itr<=math.floor(3*S.i_max/4):
                    base = 1.25
                elif S.itr>math.floor(3*S.i_max/4):
                    base = 1.1
                else:
                    base = 1.5

                print(t)

                tau = base**t[0]
                print('tau: ' + str(tau))
                S.xnew.values[i_coord] = tau*S.xcurrent.values[i_coord]

            #Check if this solution has been tested previously
            for x in range(0,len(S.TestedSolutions)):
                 if np.array_equal( S.TestedSolutions[x], np.array(S.xnew.values) ):
                     print('Identical weights already used, reselecting...')
                     xunique = False
                     break
                 else:
                     xunique = True
            #all(first == x for x in iterator)

        print('Weights: ' + str(S.xnew.values))
        print('tested weights: ' + str(S.TestedSolutions))
        #xunique = True
            

        print('tracking weights: ' + str(S.xnew))
        #=========================================
        # Assign Task set values to Task List
        #=========================================
        S.trackingWeights = S.xnew
        taskSetFilenametemplate = os.path.join(self.fileset.trialpath,'RRA_Tasks.xml')
        taskSetFilename = os.path.join(self.fileset.optpath,'Tasks','optItr_'+str(S.itr)+'_Tasks.xml')
        newtaskSetFilename = self.__writeTrackingWeights__(taskSetFilenametemplate,taskSetFilename,S.trackingWeights)

        #=====================================
        #Run RRA with current iteration values
        #=====================================

        #load RRATool to assess trial variables and update RRA tool for opt itrs.
        rratool = osim.RRATool(os.path.join(self.fileset.trialpath,self.fileset.rrasetupfile))

        rratool.setName('optItr') # overwrite existing results to save drive space. Otherwise, append tool name with num2str(itr). JS
        rratool.setModelFilename(os.path.join(self.fileset.trialpath,self.fileset.adjname))
        rratool.setOutputModelFileName(os.path.join(self.fileset.optpath,self.fileset.adjname))
        rratool.setResultsDir(os.path.join(self.fileset.optpath,'Results'))
        rratool.setTaskSetFileName(newtaskSetFilename)
        rratool.setMaximumNumberOfSteps(20000)
        rraSetupFile = os.path.join(self.fileset.optpath,'optItr_'+str(S.itr)+'_Setup.xml')
        rratool.printToXML(rraSetupFile)

        mydir = os.getcwd()
        os.chdir(os.path.join(self.fileset.optpath,'Results'))
        command_rra = 'opensim-cmd run-tool ' + rraSetupFile
        os.system(command_rra)
        os.chdir(mydir)

        #------------------------
        #Evaluate RRA results
        #------------------------
        #Calculate new objective function value
        mod = osim.Model(os.path.join(self.fileset.trialpath,self.fileset.adjname))
        state = mod.initSystem()
        body_mass = mod.getTotalMass(state)

        S = self.__calculateObjectiveFunction__(S,body_mass)

        #Store the solutions we have explored
        S.TestedSolutions.append(np.array(S.xnew.values))
        S.ObjFuncValues = np.append(S.ObjFuncValues,S.fnew)

        return(S)


    #****************************************************************************
    # Function: Framework for initalizing optimization loop using parallel or std
    def __executeRRAOptLoop__(self,S,body_mass):
        print('entering opt loop')

        #Display current iteration


        if S.itr>0:
            print('Current OF value: ',str(S.ObjFuncValues[S.itr]))
            print('Initial OF value: ',str(S.ObjFuncValues[0]))

        print(' ')

        #Generate new RRA solution
        S.itr = S.itr+1
        S = self.__RHCP_itr__(S,body_mass)
        
        #---------------------------------------------------------------------
        # update the full matrix of optimization variables with values from
        # each parallel computed trial
        
        #S.TestedSolutions.append([S_itr.TestedSolutions])
        #S.ObjFuncValues = np.append(S.ObjFuncValues,S_itr.fnew)
        #S.sumRMSResiduals = np.append(S.sumRMSResiduals,S_itr.sumRMSResiduals)
        #S.sumRMSErrors = np.append(S.sumRMSErrors,S_itr.sumRMSErrors)
        #S.sumRMSForces = np.append(S.sumRMSForces,S_itr.sumRMSForces)
        #S.sumRMSMoments = np.append(S.sumRMSMoments,S_itr.sumRMSMoments)

        #check for improved objective function measures 
        #If we found a better solution, store it
        if S.fnew < S.fcurrent: #S_itr.fnew < S.fcurrent:
            S.xcurrent = S.xnew #S_itr.xnew
            S.fcurrent = S.fnew #S_itr.fnew

        S_file = os.path.join(self.fileset.optpath,'opt_results.optStruct')

        #import pickle

        print('saving results file to: ' + S_file)
        with open(S_file,'wb') as struct_file:
            pickle.dump(S,struct_file)
        
        return(S)

    # define data class to store optimization configuration and results
    class _optStruct:
        def __init__(self):
            self.itr = 0
            self.wRes = 1
            self.wErr = 1
            self.pRes =  1
            self.pErr = 1
            self.trackingWeights = rrasetup._weightStruct()
            self.xnew = rrasetup._weightStruct()
            self.fnew = 0
            self.thresh = 2
            self.i_min = 25
            self.i_max = 75
            self.xcurrent = rrasetup._weightStruct()
            self.TestedSolutions = [[]] 
            self.ObjFuncValues = []
            self.fcurrent = 0
            self.sumRMSResiduals = []
            self.sumRMSErrors = []
            self.sumRMSForces = []
            self.sumRMSMoments = []

    # define data class to store traking weights info
    class _weightStruct:
        def __init__(self):
            self.names = []
            self.values = []
            self.rmsErr = []
            self.rmsNormFactor = []

# define data class for file paths and names used in RRA scheme. Is used as a property in the main class
class rrafiles:
    def __init__(self, trialpath, participant, condition):
        self.trialpath = trialpath
        self.resultspath = os.path.join(self.trialpath,"RRA_inital")
        self.adjresultspath = os.path.join(self.trialpath,"RRA_adjMass")
        self.optpath = os.path.join(self.trialpath,"RRA_optWeights")
        self.finalpath = os.path.join(self.trialpath,"RRA_Final")
        
        if condition:
            self.modelname = ''.join(participant + '_' + condition + '.osim')
        elif not condition:
            self.modelname = ''.join(participant + '.osim')

        self.outname = self.modelname.replace(".osim","_adjMass.osim")
        self.adjname = self.modelname.replace(".osim","_adj.osim")
        self.optname = self.modelname.replace(".osim","_Final.osim")
        self.kinfile = 'Visual3d_SIMM_input.mot'
        self.grffile = 'Visual3d_SIMM_grf.mot'
        self.extloadsetup = 'External_Loads_grf.xml'
        self.actuatorfile = 'RRA_reserves.xml'
        self.taskfile = 'RRA_tasks.xml'
        self.rrasetupfile = 'RRA_Setup.xml'
        self.masssetupfile = 'RRA_Setup_massItrs.xml'
        self.genericsetup = 'DrFrankenSpine_RRA_Setup.xml'


        
# define data class used to setup the OpenSim RRAtool. Is used as a property in the main class         
class rraoptions:
    def __init__(self,starttime,endtime,bForceset,bAdjustCOM,comBody,trialpath,modelname,actuatorfile,extloadsetup,kinfile,taskfile,resultspath,outname,rrasetupfile):
        self.starttime = starttime
        self.endtime = endtime
        self.bForceset = bForceset
        self.bAdjustCOM = bAdjustCOM
        self.comBody = comBody
        self.trialpath = trialpath
        self.modelname = modelname
        self.actuatorfile = actuatorfile
        self.extloadsetup = extloadsetup
        self.kinfile = kinfile
        self.taskfile = taskfile
        self.resultspath = resultspath
        self.outname = outname
        self.rrasetupfile = rrasetupfile
    

# %%
