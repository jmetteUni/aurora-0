
%addpath .:/tmd_toolbox
%addpath ./tmd_toolbox/FUNCTIONS
%addpath ./t_tide_v1.3beta
gridname = 'grid-M512L512';
gfile= fullfile('/home/jonathan/Dokumente/model/roms_project/aurora-0/matlab/',strcat(gridname,'.nc'));   %grid file
base_date=datenum(2022,07,26);
pred_date=datenum(2022,07,26);      %ref for nodal corrections; meaning??
ofile= fullfile('/home/jonathan/Dokumente/model/roms_project/aurora-0/matlab/',strcat(gridname,'_tides','.nc'));    %output file name
model_file='/home/jonathan/Dokumente/model/inputs/Tides/otps/arctic_tide/data/Model_Arc5km2018';  %tide model file
otps2frc_v5(gfile,base_date,pred_date,ofile,model_file,'AURORA')  %Espresso == arbitrary domain name
