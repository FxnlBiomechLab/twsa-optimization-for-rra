classdef extloadoptions
    properties
        forceName_left
        forceName_right
        appliedBody_left
        appliedBody_right
        forceID_left
        pointID_left
        torqueID_left
        forceID_right
        pointID_right
        torqueID_right
        expressedInBody
    end
    methods
        function obj = extloadoptions()
            obj.forceName_left = 'ExternalForce_2';
            obj.forceName_right = 'ExternalForce_1';
            obj.appliedBody_left = 'calcn_l';
            obj.appliedBody_right = 'calcn_r';
            obj.forceID_left = 'l_ground_force_v';
            obj.pointID_left = 'l_ground_force_p';
            obj.torqueID_left = 'l_ground_torque';
            obj.forceID_right = 'ground_force_v';
            obj.pointID_right = 'ground_force_p';
            obj.torqueID_right = 'ground_torque';
            obj.expressedInBody = 'ground';
        end
    end   
end