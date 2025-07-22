DROP SCHEMA IF EXISTS stage_locations CASCADE;
CREATE SCHEMA IF NOT EXISTS stage_locations;

IMPORT FOREIGN SCHEMA public
	LIMIT TO (
		"Locations",

		"LocationDynamicControlValues",
		"DynamicControls",
		"DynamicControlOptions",
		"DynamicControlRoleMappings",
		"DynamicControlLocationMappings"		
	)
	FROM SERVER locationsapi_srv INTO stage_locations;


ALTER TABLE stage_locations."LocationDynamicControlValues" RENAME TO location_dynamic_control_values_l;
ALTER TABLE stage_locations."DynamicControls" 				RENAME TO dynamic_controls_l;
ALTER TABLE stage_locations."DynamicControlOptions" 		RENAME TO dynamic_control_options_l;
ALTER TABLE stage_locations."DynamicControlLocationMappings"	RENAME TO dynamic_control_location_mappings_l;
ALTER TABLE stage_locations."DynamicControlRoleMappings" 	RENAME TO dynamic_control_role_mappings_l;


