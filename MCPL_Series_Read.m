clear all;
close all;

%Include directories to external GIT libraries
Include_Subdirectories({'Data_Operations','File_Operations','Input_Validation','Parpool', 'Waitbar', 'WinRAR', 'MCPL_Functions'});
%% Test Data
%32 bit data for testing
Directory_Path = 'D:\Data_Capture\Alex_Hex\data';
%Directory_Path = 'D:\Data_Capture\0Deg\data';
List_File_Path = Search_Files(Directory_Path, '.mcpl');
Merged_Filename = 'merged';

[Root_File_Path, Filename, ~] = fileparts(Directory_Path);
Merged_File_Path = fullfile(Root_File_Path, strcat(Merged_Filename, ".mat"));
%% Parameters for WinRAR implementation
%Path to WinRAR executable
%RAR_Parameters.WinRAR_Path = 'C:\Program Files\WinRAR\WinRAR.exe';
%By default overwrite any files already existing
RAR_Parameters.Overwrite_Mode = true;

%% Parameters for MCPL processing to MAT file
%If events are sorted in descending order of weight with the most significant events at the top of the file. (true = sort)
Read_Parameters.Sort_Events_By_Weight = true;
%If events with exactly 0 w5eighting (represent no photons) are to be removed (true = removed)
Read_Parameters.Remove_Zero_Weights = true;
%If retaining EKinDir data (reccomended setting to true if wanting to later use subsequent data in simulations)
Read_Parameters.Save_EKinDir = true;
%If the GZ archive has already been uncompressed or not (if problems with WinRAR, can bypass decompression)
Read_Parameters.Skip_Uncompress = true;
%Number of cores for the Parpool to use when converting the raw MCPL file (integer)
Read_Parameters.Parpool_Num_Cores = 1;
%Temporary directory to use for constructing / operating on datastore
Read_Parameters.Temp_Directory = 'F:\Windows_Temp_Files';
%Add RAR Parameters to the Read Parameters
Read_Parameters.RAR_Parameters = RAR_Parameters;

Display_Write_Progress = true;
%% Convert MCPL file to MAT file format
tic
Mat_File_Path = MCPL_To_MAT(Directory_Path, Read_Parameters);
toc
Mat_File_Path = MCPL_Merge_Files(Mat_File_Path, Merged_File_Path, false);
load(Mat_File_Path);
Event_Angle = acosd(Dz);

figure();
scatter3(X, Y, Z, [], Event_Angle, '.');
xlabel('X [m]');
ylabel('Y [m]');

figure();
scatter3(Dx, Dy, Dz, [], Event_Angle, '.');
xlabel('X [m]');
ylabel('Y [m]');

figure();
histogram(Event_Angle);
xlabel(['Incident Angle [', char(176), ']']);
ylabel('Frequency');

figure();
scatter3(X, Y, Event_Angle, [], Event_Angle, '.');
xlabel('X [m]');
ylabel('Y [m]');

Z_Target = 397e-3;
%Find propogation vector
Prop = (Z_Target - Z)./Dz;
%Calculate propotation points in X,Y,Z
Prop_Z = Prop .* Dz + Z;
Prop_X = Prop .* Dx + X;
Prop_Y = Prop .* Dy + Y;
%Display propogated data
scatter3(Prop_X, Prop_Y, Prop_Z, [], Event_Angle, '.');

%Rebinning parameters
Bins_Num = 250;
Bin_Tol = 0.1e-3;
%Create bins
X_Bins = linspace(min(Prop_X(:)) - Bin_Tol, max(Prop_X(:)) + Bin_Tol, Bins_Num + 1);
Y_Bins = linspace(min(Prop_Y(:)) - Bin_Tol, max(Prop_Y(:)) + Bin_Tol, Bins_Num + 1);
[Grid_X, Grid_Y] = ndgrid(X_Bins, Y_Bins);
Weighted_Binned_Angle_Mean = zeros(size(Grid_X));
Weighted_Binned_Angle_Std = zeros(size(Grid_X));
for Current_X = 1:length(X_Bins) - 1
    for Current_Y = 1:length(Y_Bins) - 1
        Index = ((X_Bins(Current_X) < Prop_X) & (Prop_X <= X_Bins(Current_X + 1))) & (Y_Bins(Current_Y) < Prop_Y) & (Prop_Y <= Y_Bins(Current_Y + 1));
        Weighted_Angle = Event_Angle(Index) .* (Weight(Index) ./ sum(Weight(Index), 'omitnan'));
        %Weighted_Angle = Event_Angle(Index);
        Weighted_Binned_Angle_Mean(Current_X, Current_Y) = mean(Weighted_Angle);
        Weighted_Binned_Angle_Std(Current_X, Current_Y) = std(Weighted_Angle);
    end
end
figure();
Surf_Fig = surf(Grid_X, Grid_Y, min(zlim())*ones(size(Grid_X)), Weighted_Binned_Angle_Mean,'FaceAlpha', .8);
set(Surf_Fig, 'linestyle', 'none');
figure();
Surf_Fig = surf(Grid_X, Grid_Y, min(zlim())*ones(size(Grid_X)), Weighted_Binned_Angle_Std,'FaceAlpha', .8);
set(Surf_Fig, 'linestyle', 'none');
%Create binned 2d histogram for x-y data
% xzCount = histcounts2(Prop_X(:), Prop_Y(:), X_Bins, Y_Bins);
% figure();
% surf(Grid_X, Grid_Y, min(zlim())*ones(size(Grid_X)), xzCount,'FaceAlpha', .8);



%Perform work on the MAT file
% for Current_Mat_File = 1:length(Mat_File_Path)
%     %Create new directory to place processed files into
%     [Output_Directory, Filename, Extension] = fileparts(Mat_File_Path{Current_Mat_File});
%     Parent_Directory = fileparts(Output_Directory);
%     Output_Directory = fullfile(Parent_Directory, 'Processed-Output');
%     Attempt_Directory_Creation(Output_Directory);
% 
%     %% Filter data within the MAT file
%     %Position the events land on the detection plane
% %     Filters.X.Min = -0.04;
% %     Filters.X.Max = 0.04;
% %     Filters.Y.Min = -0.04;
% %     Filters.Y.Max = 0.04;
% %     %Filters.Z.Min = 0;
% %     %Filters.Z.Max = 1;
% %     %Angle from the normal (to Z), must be +ve valued
% %     Filters.Angle.Min = 0;
% %     Filters.Angle.Max = 45;
% %     %Energy [KeV]
% %     Filters.Energy.Min = 0;
% %     Filters.Energy.Max = 130;
% %     %Weighting
% %     Filters.Weight.Min = 0.1;
%     %Filters.Weight.Max = 35;
%     Filters.Photons.Min = 0.05;
%     %Filters.Photons.Max = 35;
%     Filters.Photons.Interval = 0.01;
%     
%     %Create filepath for the filtered MAT file
%     Filtered_Mat_File_Path{Current_Mat_File} = fullfile(Output_Directory, strcat(Filename, '-Filtered', Extension));
%     %Filter the file according to parameters previously set
%     tic
%     Filtered_Mat_File = MCPL_Filter_MAT_Data(Mat_File_Path{Current_Mat_File}, Filtered_Mat_File_Path{Current_Mat_File}, Filters);
%     toc
%     
%     %Create filepath for the Recreated MCPL file
%     MCPL_Filepath = fullfile(Output_Directory, strcat(Filename, '-Processed.MCPL'));
%     %Convert MAT file back to an MCPL file
%     tic
%     MCPL_File = MAT_To_MCPL(Filtered_Mat_File, MCPL_Filepath, Display_Write_Progress);
%     toc
%     %Test extraction of MCPL file (only for comparison if not filtering data)
%     %Mat_File_Path_2 = MCPL_To_MAT(MCPL_File, Read_Parameters);
%     % Compare initial MAT and recreated MAT files match
%     %visdiff(Mat_File_Path{Current_Mat_File}, Mat_File_Path_2{1});
% end