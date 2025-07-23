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


ALTER TABLE stage_locations."LocationDynamicControlValues"  RENAME TO dc_values_l;
ALTER TABLE stage_locations."DynamicControls" 				RENAME TO dc_l;
ALTER TABLE stage_locations."DynamicControlOptions" 		RENAME TO dc_options_l;
ALTER TABLE stage_locations."DynamicControlLocationMappings"	RENAME TO dc_location_mappings_l;
ALTER TABLE stage_locations."DynamicControlRoleMappings" 	RENAME TO dc_role_mappings_l;


