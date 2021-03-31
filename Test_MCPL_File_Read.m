clear all;
close all;

%Include directories to external GIT libraries
Include_Subdirectories({'Parpool','WinRAR','File_Operations', 'Input_Validation', 'Data_Operations'});

%% Test Data
%32 bit data for testing
File_Path = 'D:\MCPL_Output_Diffraction_Test_20210304_145727\MCPL_Output_No_Polarisation_Single_Precision.mcpl.gz';
%64 bit data for testing
%File_Path = 'D:\MCPL_Output_Diffraction_Test_20210303_211044\MCPL_Output_Diffraction_Test_1.mcpl.gz';
%64 bit dataset (small file)
File_Path = 'D:\MCPL_Output_Diffraction_Test_20210329_171051\MCPL_Output_Diffraction_Test_DBL.mcpl.gz';

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

%Perform work on the MAT file
for Current_Mat_File = 1:length(Mat_File_Path)
    %Create new filepath for the MAT file to end up in
    [Directory, Filename, Extension] = fileparts(Mat_File_Path{Current_Mat_File});
    Parent_Directory = fileparts(Directory);
    Output_Directory = fullfile(Parent_Directory, 'DEBUG');
    Attempt_Directory_Creation(Output_Directory);
    MCPL_Filepath = fullfile(Output_Directory, strcat(Filename, '.MCPL'));
    
    %% Filter data within the MAT file
    %Position the events land on the detection plane
    Filters.X.Min = -0.05;
    Filters.X.Max = 0.05;
    Filters.Y.Min = -0.05;
    Filters.Y.Max = 0.05;
    Filters.Z.Min = -0.05;
    Filters.Z.Max = 0.05;
    %Angle from the normal (to Z), must be +ve valued
    Filters.Angle.Min = 1;
    Filters.Angle.Max = 5;
    %Energy [KeV]
    Filters.Energy.Min = 10;
    Filters.Energy.Max = 60;
    %Weighting
    Filters.Weight.Min = 1;
    Filters.Weight.Max = 20;
    %Create filepath for the filtered MAT file
    Filtered_Mat_File_Path{Current_Mat_File} = strcat(Mat_File_Path{Current_Mat_File}, '-Filtered');
    Filtered_Mat_File = Filter_MPCL_MAT_Data(Mat_File_Path{Current_Mat_File}, Filtered_Mat_File_Path{Current_Mat_File}, Filters);
    
    %Convert MAT file back to an MCPL file
    MCPL_File = MAT_To_MCPL(Mat_File_Path{Current_Mat_File}, MCPL_Filepath);
    
    %Test extraction of MCPL file
    Mat_File_Path_2 = MCPL_To_MAT(MCPL_File, Read_Parameters);
    
    % Compare initial MAT and recreated MAT files match (would expect only the header to differ due to different chunk splitting of files)
    %visdiff(Mat_File_Path{1}, Mat_File_Path_2{1});
end