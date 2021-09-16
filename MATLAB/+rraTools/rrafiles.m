classdef rrafiles
    properties
        trialpath
        resultspath
        adjresultspath
        optpath
        finalpath
        modelname
        outname
        adjname
        optname
        kinfile
        grffile
        extloadsetup
        actuatorfile 
        taskfile
        rrasetupfile
        masssetupfile
        genericsetup
    end
    methods
        function obj = rrafiles(trialpath, participant, condition)
            obj.trialpath = trialpath;
            obj.resultspath = fullfile(obj.trialpath,"RRA_initial");
            obj.adjresultspath = fullfile(obj.trialpath,"RRA_massItrs");
            obj.optpath = fullfile(obj.trialpath,"RRA_optWeights");
            obj.finalpath = fullfile(obj.trialpath,"RRA_Final");
            if isempty(condition)
                obj.modelname = [participant, '.osim'];
            else
                obj.modelname = [participant, '_', condition, '.osim'];
            end
            obj.outname = strrep(obj.modelname,'.osim','_adjMass.osim');
            obj.adjname = strrep(obj.modelname,'.osim','_adj.osim');
            obj.optname = strrep(obj.modelname,'.osim','_Final.osim');
            obj.kinfile = 'Visual3d_SIMM_input.mot';
            obj.grffile = 'Visual3d_SIMM_grf.mot';
            obj.extloadsetup = 'External_Loads_grf.xml';
            obj.actuatorfile = 'RRA_reserves.xml';
            obj.taskfile = 'RRA_tasks.xml';
            obj.rrasetupfile = 'RRA_Setup.xml';
            obj.masssetupfile = 'RRA_Setup_massItrs.xml';
            obj.genericsetup = 'RRA_Setup.xml';
        end
    end   
end