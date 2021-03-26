clear all;
close all;

%Include directories to external GIT libraries
Include_Subdirectories({'Parpool','WinRAR','File_Operations', 'Input_Validation', 'Data_Operations'});

%% Test Data
%32 bit data for testing
File_Path = 'D:\MCPL_Output_Diffraction_Test_20210304_145727\MCPL_Output_No_Polarisation_Single_Precision.mcpl.gz';
%64 bit data for testing
%File_Path = 'D:\MCPL_Output_Diffraction_Test_20210303_211044\MCPL_Output_Diffraction_Test_1.mcpl.gz';

%% Parameters for WinRAR implementation
%Path to WinRAR executable
RAR_Parameters.WinRAR_Path = 'C:\Program Files\WinRAR\WinRAR.exe';
%By default overwrite any files already existing
RAR_Parameters.Overwrite_Mode = true;

%% Parameters for MCPL processing to MAT file
%If events are sorted in descending order of weight with the most significant events at the top of the file. (true = sort)
Read_Parameters.Sort_Events_By_Weight = true;
%If events with exactly 0 weighting (represent no photons) are to be removed (true = removed)
Read_Parameters.Remove_Zero_Weights = true;
%If the temporary files created during processing are deleted (true = delete temp files)
Read_Parameters.Remove_Temp_Files = true;
%If the GZ archive has already been uncompressed or not (if problems with WinRAR, can bypass decompression)
Read_Parameters.Skip_Uncompress = false;
%Number of cores for the Parpool to use when converting the raw MCPL file (integer)
Read_Parameters.Parpool_Num_Cores = 6;
%Add RAR Parameters to the Read Parameters
Read_Parameters.RAR_Parameters = RAR_Parameters;

%% Convert MCPL file to MAT file format
Mat_File_Path = MCPL_To_MAT(File_Path, Read_Parameters);