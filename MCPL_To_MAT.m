%% Reads MCPL file and converts it to a MAT file
function MAT_File_Path = MCPL_To_MAT(MCPL_File_Path, Read_Parameters)
    %% Input handling
    if(nargin == 0)
        error("MCPL_To_MAT : File path Input Required.");
    elseif(nargin == 1)
        if(~(isstring(MCPL_File_Path) || ischar(MCPL_File_Path)))
            error("MCPL_To_MAT : Expected File Path to be a single string.");
        end
        warning("MCPL_To_MAT : No read parameters supplied, using default settings.");
    end
    if(nargin == 2)
        if(~isstruct(Read_Parameters))
            error("MCPL_To_MAT : Expected Read Parameters to be a structure.");
        end
    end
    if(~exist('Read_Parameters','var'))
        Read_Parameters = struct();
    end
    %Skipping decompression
    [Struct_Var_Value, Struct_Var_Valid] = Verify_Structure_Input(Read_Parameters, 'Skip_Uncompress', false);
    if(Struct_Var_Valid)
        Skip_Uncompress = Struct_Var_Value;
    else
        Skip_Uncompress = false;
    end
    %Sorting events by weighting
    [Struct_Var_Value, Struct_Var_Valid] = Verify_Structure_Input(Read_Parameters, 'Sort_Events_By_Weight', true);
    if(Struct_Var_Valid)
        Sort_Events_By_Weight = Struct_Var_Value;
    else
        Sort_Events_By_Weight = true;
    end
    %Removal of 0 weight events
    [Struct_Var_Value, Struct_Var_Valid] = Verify_Structure_Input(Read_Parameters, 'Remove_Zero_Weights', true);
    if(Struct_Var_Valid)
        Remove_Zero_Weights = Struct_Var_Value;
    else
        Remove_Zero_Weights = true;
    end
    %Number of cores used for the parallel core reading
    [Struct_Var_Value, Struct_Var_Valid] = Verify_Structure_Input(Read_Parameters, 'Parpool_Num_Cores', 1);
    if(Struct_Var_Valid)
        Parpool_Num_Cores = Struct_Var_Value;
    else
        Parpool_Num_Cores = 1;
    end
    %If changing the temporary directory for using datastores
    [Struct_Var_Value, Struct_Var_Valid, Struct_Var_Default_Used] = Verify_Structure_Input(Read_Parameters, 'Temp_Directory', '');
    if(Struct_Var_Valid && ~Struct_Var_Default_Used)
        if(~isfolder(Struct_Var_Value))
            User_Input = input('Temporary Directory does not exist, create? (Y / N): ', 's');
            if(strcmpi(User_Input, 'Y'))
                Directory_Create_Success = Attempt_Directory_Creation(Struct_Var_Value);
                if(~Directory_Create_Success)
                    error("MCPL_To_MAT : Failed to create temporary directory.");
                end
            else
                error("MCPL_To_MAT : Ending Execution.");
            end
        end
        %Set matlab to use the temporary directory specified rather than the default system temp directory
        setenv('TEMP', Struct_Var_Value);
        setenv('TMP', Struct_Var_Value);
    end
    %If retaining EKinDir in the output files
    [Struct_Var_Value, Struct_Var_Valid] = Verify_Structure_Input(Read_Parameters, 'Save_EKinDir', false);
    if(Struct_Var_Valid)
        Save_EKinDir = Struct_Var_Value;
    else
        Save_EKinDir = false;
    end
    clear Struct_Var_Value Struct_Var_Valid Struct_Var_Default_Used;
    
    %% If the file path supplied is a file
    if(isfile(MCPL_File_Path))
        [Directory_Path, Filename, Extension] = fileparts(MCPL_File_Path);
        %% Switch treatment of file format based on file format
        if(any(strcmpi(Extension, {'.gz', '.rar', '.zip'})))
            %Extraction of GZ archive (if the file format matches)
            Uncompressed_File_Path = strcat(Directory_Path, filesep, Filename, '-UNCOMPRESSED');
            %Only use RAR_Parameters field if it has been parsed by previous settings structure
            if(isfield(Read_Parameters, 'RAR_Parameters'))
                RAR_Parameters = Read_Parameters.RAR_Parameters;
            else
                RAR_Parameters = struct();
            end
            if(~Skip_Uncompress)
                disp("MCPL_To_MAT : Attempting to uncompress .GZ archive.");
                Successful_Uncompress = UNRAR(MCPL_File_Path, Uncompressed_File_Path, RAR_Parameters);
            else
                Successful_Uncompress = 1;
            end
            clear Skip_Uncompress RAR_Parameters;
            if(~Successful_Uncompress)
                error('MCPL_To_MAT : Error uncompressing GZ file format.');
            end
            MCPL_File_List = {};
            File_Path_Search = Uncompressed_File_Path;
            clear Successful_Uncompress Uncompressed_File_Path;
        elseif(strcmpi(Extension, '.mcpl'))
            %No extraction required, single uncompressed MCPL file supplied
            MCPL_File_List{1} = MCPL_File_Path;
            File_Path_Search = MCPL_File_Path;
        elseif(strcmpi(Extension, '.xbd'))
            %Single XBD file
            MCPL_File_List{1} = MCPL_File_Path;
            File_Path_Search = MCPL_File_Path;
        else
            error('MCPL_To_MAT : Unexpected file format');
        end
    elseif(isfolder(MCPL_File_Path))
        %If a directory is supplied, search the directory path for MCPL
        %files
        File_Path_Search = MCPL_File_Path;
        MCPL_File_List = {};
    else
        error('MCPL_To_MAT : Input File or Directory does not exist.');
    end
    clear Extension Filename Directory_Path MCPL_File_Path;

    %% Find MCPL file(s) that aren't explicitly stated in the original input (if a directory is specified)
    if(isempty(MCPL_File_List))
        %Find all mcpl files in the directory
        MCPL_File_Search = Search_Files(File_Path_Search, '.mcpl');
        XBD_File_Search = Search_Files(File_Path_Search, '.xbd');
        %Check directory lists aren't empty
        if(isequal(MCPL_File_Search, struct()))
            if(isequal(XBD_File_Search, struct()))
                error('MCPL_To_MAT : No MCPL or XBD files found.');
                MCPL_File_List = [];
            else
                MCPL_File_List = XBD_File_Search;
            end
        else
            if(isequal(XBD_File_Search, struct()))
                MCPL_File_List = MCPL_File_Search;
            else
                MCPL_File_List = [MCPL_File_Search, XBD_File_Search];
            end
        end
    else
        %Get file path to file as a directory structure, no need to search
        MCPL_File_List = dir(MCPL_File_List{1});
    end
    if(isempty(fieldnames(MCPL_File_List)))
        error('MCPL_To_MAT : No .MCPL files found');
    end
    if(isempty(MCPL_File_List))
        error('MCPL_To_MAT : No .MCPL files found within Directory');
    end
    clear File_Path_Search;
    
    %% Parallel core processing setup
    if(Parpool_Num_Cores > 1)
        Parpool = Parpool_Create(Parpool_Num_Cores);
    end
    
    %Preallocate the list of file paths
    MAT_File_Path{length(MCPL_File_List)} = '';
    %% Read MCPL or XBD files into temporary MAT files
    for Read_Index = 1:length(MCPL_File_List)
        %Path and reference to file
        File_Path = fullfile(MCPL_File_List(Read_Index).folder, filesep, MCPL_File_List(Read_Index).name);
        %Determine how to handle the two different file formats (MCPL / XBD)
        [~, ~, Extension] = fileparts(File_Path);
        %% Switches for MCPL and XBD file reading (File.Type = 1 for MCPL, File.Type = 2 for XBD)
        if(strcmpi(Extension, '.mcpl'))
            disp(strcat("MCPL_To_MAT : Reading MCPL file : ", File_Path));
            File.Type = 1;
        elseif(strcmpi(Extension, '.xbd'))
            disp(strcat("MCPL_To_MAT : Reading XBD file : ", File_Path));
            File.Type = 2;
        else
            error(strcat("MCPL_To_MAT : Unknown file extension for file : ", File_Path));
        end
        File_ID = fopen(File_Path, 'r');
        %% Read file header
        if(File.Type == 1)
            disp("MCPL_To_MAT : Reading MCPL Header");
            Header = MCPL_Read_Header(File_ID);
        elseif(File.Type == 2)
            disp("MCPL_To_MAT : Creating placeholder MCPL Header for XBD file");
            Header.Endian_Switch = 0;
            Header.Endian.T32 = 'l';
            Header.Endian.T64 = 'a';
            Header.MCPL_Version = 3;
            Header.Particles = 0;
            Header.Opt_Userflag = 0;
            Header.Opt_Polarisation = 0;
            Header.Opt_SinglePrecision = 0;
            Header.Opt_UniversalPDGCode = 22;
            Header.Opt_ParticleSize = 64;
            Header.Opt_UniversalWeight = 0;
            Header.Opt_Signature = 0 + 1*Header.Opt_SinglePrecision + 2*Header.Opt_Polarisation + 4*Header.Opt_UniversalPDGCode + 8*Header.Opt_UniversalWeight + 16*Header.Opt_Userflag;
            Header.Source = {'X-ray Binary Data'};
            Header.Comments = {'Output by COMPONENT: Save_State'};
            Header.Blobs.Key{1} = 'mccode_instr_file';
            Header.Blobs.Key{2} = 'mccode_cmd_line';
            Header.Blobs.Data{1} = 'XBD File: No inbuilt instrument file';
            Header.Blobs.Data{2} = 'XBD File: No inbuilt instrument cmd line';
            Header.End = 0;
            Header.Valid = 1;
        else
            error("MCPL_To_MAT : Unknown file type");
        end
        %If saving raw EKinDir
        Header.Save_EKinDir = Save_EKinDir;
        %Error correction for MCPL files with universal weight flag set
        if(Header.Opt_UniversalWeight)
            if(Header.Sort_Events_By_Weight)
                Header.Sort_Events_By_Weight = false;
                disp("MCPL_To_MAT : Sorting events by weight disabled due to universal weighting.");
            end
        end
        %Get size of file
        fseek(File_ID, 0, 'eof');
        File.End = ftell(File_ID);
        File.Data = File.End - Header.End;
        fseek(File_ID, Header.End, 'bof');
        Successful_Close = fclose(File_ID);
        if(Successful_Close == -1)
            warning(["MCPL_To_MAT : File failed to close: ", MCPL_File_List(Read_Index).name]);
        end
        %Find size of a single photon's information from header information
        if(Header.Valid)
            %% Prep for reading data
            %Variable type data
            if(Header.Opt_SinglePrecision)
                Byte_Size = 4;
                Byte_Type = 'single';
            else
                Byte_Size = 8;
                Byte_Type = 'double';
            end
            %Add bit depth information to header information
            Header.Byte_Size = Byte_Size;
            Header.Byte_Type = Byte_Type;
            %Tracking the byte position of specific data within a single photon's data
            Event_Byte_Count = 0;
            if(File.Type == 1)
                %Dynamic data types
                if(Header.Opt_Polarisation)
                    %Polarisation data within the photon byte string
                    [Event_Byte_Count, Byte_Split.Px.Start, Byte_Split.Px.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                    [Event_Byte_Count, Byte_Split.Py.Start, Byte_Split.Py.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                    [Event_Byte_Count, Byte_Split.Pz.Start, Byte_Split.Pz.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                end
                %Position data within the photon byte string
                [Event_Byte_Count, Byte_Split.X.Start, Byte_Split.X.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Y.Start, Byte_Split.Y.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Z.Start, Byte_Split.Z.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Displacement/Energy Vectors within the photon byte string
                [Event_Byte_Count, Byte_Split.EKinDir_1.Start, Byte_Split.EKinDir_1.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.EKinDir_2.Start, Byte_Split.EKinDir_2.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.EKinDir_3.Start, Byte_Split.EKinDir_3.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Time within the photon byte string
                [Event_Byte_Count, Byte_Split.Time.Start, Byte_Split.Time.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Weight within the photon byte string (if exists)
                if(~Header.Opt_UniversalWeight)
                    [Event_Byte_Count, Byte_Split.Weight.Start, Byte_Split.Weight.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                end
                
                %Static Data Types
                %PDGCode (if exists)
                if(Header.Opt_UniversalPDGCode == 0)
                    [Event_Byte_Count, Byte_Split.PDGCode.Start, Byte_Split.PDGCode.End] = Get_Byte_Position(Event_Byte_Count, 4);
                end
                %Userlags (if exists)
                if(Header.Opt_Userflag)
                    [Event_Byte_Count, Byte_Split.UserFlag.Start, Byte_Split.UserFlag.End] = Get_Byte_Position(Event_Byte_Count, 4);
                end
                %% Calculate number of events within the file if a zero particle count is returned
                if(Header.Particles == 0)
                    Header.Particles = floor((File.End - Header.End) / Event_Byte_Count);
                    File.End = Header.End + (Header.Particles * Event_Byte_Count);
                    File.Data = File.End - Header.End;
                end
            elseif(File.Type == 2)
                %Position data within the photon byte string
                [Event_Byte_Count, Byte_Split.X.Start, Byte_Split.X.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Y.Start, Byte_Split.Y.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Z.Start, Byte_Split.Z.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Direction Vector data within the photon byte string
                [Event_Byte_Count, Byte_Split.Dx.Start, Byte_Split.Dx.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Dy.Start, Byte_Split.Dy.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                [Event_Byte_Count, Byte_Split.Dz.Start, Byte_Split.Dz.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Weight within the photon byte string
                [Event_Byte_Count, Byte_Split.Weight.Start, Byte_Split.Weight.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %Energy within the photon byte string
                [Event_Byte_Count, Byte_Split.Energy.Start, Byte_Split.Energy.End] = Get_Byte_Position(Event_Byte_Count, Byte_Size);
                %% Calculate number of events within the XBD file
                Header.Particles = (File.End - Header.End) / Event_Byte_Count;
            end
            %Add additional fields to header
            Header.File_Type = File.Type;
            if(isfield(Header, 'Opt_ParticleSize'))
                if(Header.Opt_ParticleSize ~= Event_Byte_Count)
                    warning("MCPL To MAT : Particle size listed in file doesn't match split data");
                    Header.Opt_ParticleSize = Event_Byte_Count;
                end
            else
                Header.Opt_ParticleSize = Header.Opt_ParticleSize;
            end
            Header.Byte_Split = Byte_Split;
            Header.Sort_Events_By_Weight = Sort_Events_By_Weight;
            Header.Remove_Zero_Weights = Remove_Zero_Weights;

            %% Create root output directory
            Temp_Output_File_Root = fullfile(MCPL_File_List(Read_Index).folder, filesep, 'TEMPORARY');
            Directory_Creation_Success = Attempt_Directory_Creation(Temp_Output_File_Root);
            if(~Directory_Creation_Success)
                warning(strcat("MCPL_To_MAT : Failed to create temporary output directory for: ", MCPL_File_List(Read_Index).name));
            end
            if(File.Type == 1)
                disp("MCPL_To_MAT : Reading MCPL Data");
            elseif(File.Type == 2)
                disp("MCPL_To_MAT : Reading XBD Data");
            end
            %If parpool is disabled; requires the number of cores to be assigned to a variable
            if(~exist('Parpool', 'var'))
                Parpool.NumWorkers = Parpool_Num_Cores;
            end
            if(ispc())
                [~, System_Memory] = memory;
                Physical_Memory_Available = System_Memory.PhysicalMemory.Available;
            else
                Physical_Memory_Available = javaMethod('maxMemory', javaMethod('getRuntime', 'java.lang.Runtime'));
            end
            %Calculate file chunk interval depending on available system memory and the total file size
            %Addition of 3 fields for unpacking of EKinDir(E,x,y,z) to E, Dir(x,y,z)
            %Memory compensation factor of 40% use for additional data handling overhead while processing
            Interval_Memory = floor(((Physical_Memory_Available * 0.4) / Parpool.NumWorkers) / (Header.Opt_ParticleSize + (3 * Byte_Size)));
            Interval_File = floor((File.Data / Parpool.NumWorkers) / (Header.Opt_ParticleSize + (3 * Byte_Size)));
            %Change chunk interval based on memory available and file size
            if(Interval_Memory < Interval_File)
                Interval = Interval_Memory;
            else
                Interval = Interval_File;
            end
            %% Photon Data
            Chunks = 1:Interval:Header.Particles;
            if(length(Chunks) > 1)
                %Edit final chunk (should be minor) to add any remaining photon chunks that aren't included via equal division
                %Either adds an additional chunk or appends a few extra events to the final chunk depending on discrepency
                if(Chunks(end) ~= Header.Particles)
                    if(Header.Particles - Chunks(end) > Parpool_Num_Cores)
                        Chunks(end + 1) = Header.Particles;
                    else
                        Chunks(end) = Header.Particles;
                    end
                end
                %Calculate dynamic and corrected interval
                Interval = Chunks(2:end) - Chunks(1:end-1);
                File_Chunks = struct('Chunk', num2cell(1:1:length(Chunks)-1),'Temp_File_Path', fullfile(strcat(Temp_Output_File_Root, filesep, arrayfun(@num2str, 1:1:length(Chunks)-1, 'UniformOutput', 0), '.mat')), 'Start', num2cell(((Chunks(1:end-1)-1) * Header.Opt_ParticleSize) + Header.End), 'End', num2cell(((Chunks(1:end-1)-1) + Interval - 1) * Header.Opt_ParticleSize + Header.End + 1), 'Events', num2cell(Interval));
                %End of file correction (should be a single Event)
                if(File_Chunks(end).End ~= File.End)
                    %Adjust final chunk end if required
                    File_Chunks(end).End = File.End;
                    %Adjust chunk size as per end of file
                    File_Chunks(end).Events = (File_Chunks(end).End - File_Chunks(end).Start)/Header.Opt_ParticleSize;
                end
            else
                %Fallback if insignificant number of events to break into chunks for multicore
                File_Chunks(1).Chunk = 1;
                File_Chunks(1).Temp_File_Path = fullfile(strcat(Temp_Output_File_Root, filesep, '1.mat'));
                File_Chunks(1).Start = 0;
                File_Chunks(1).End = File.End;
                File_Chunks(1).Events = Header.Particles;
            end
            %Add chunks to header
            Header.File_Chunks = File_Chunks;
            %Save header
            Header_File_Path = fullfile(Temp_Output_File_Root, 'Header.mat');
            save(Header_File_Path, '-v7.3', '-struct', 'Header');
            %% Read file chunks aand dump them to disk, sorted individual chunks by weighting
            if((Parpool_Num_Cores > 1) && (length(File_Chunks) > 1))
                %Parallel processing
                parfor Current_File_Chunk = 1:length(File_Chunks)
                    %MCPL_Dump_Data_Chunk(Header, File_Path, File_Chunks(Current_File_Chunk));
                    MCPL_Dump_Data_Chunk(Header, File_Path, Current_File_Chunk);
                end
            else
                %Single core processing
                for Current_File_Chunk = 1:length(File_Chunks)
                    %MCPL_Dump_Data_Chunk(Header, File_Path, File_Chunks(Current_File_Chunk));
                    MCPL_Dump_Data_Chunk(Header, File_Path, Current_File_Chunk);
                end
            end
            
            %% Combine all output file(s)
            if(File.Type == 1)
                disp("MCPL_To_MAT : Processing MCPL file into MAT file");
            elseif(File.Type == 2)
                disp("MCPL_To_MAT : Processing XBD file into MAT file");
            end
            
            %% Datastore processing
            %File_Chunk data loading from header
            File_Chunks = Header.File_Chunks;
            %Datastore directory
            Datastore_Directory_Path = fullfile(fileparts(File_Path), 'Datastore');
            %Load datastore files
            File_Data_Store = tall(fileDatastore({File_Chunks.Temp_File_Path}, 'ReadFcn', @(x)struct2table(load(x)), 'UniformRead', true));
            %Remove zero weights if enabled
            if(Header.Remove_Zero_Weights)
                disp("MCPL_To_MAT : Finding 0 Weight Entries to Remove.");
                Index = Floating_Point_Equal([File_Data_Store.Weight], 0);
                disp("MCPL_To_MAT : Finding Total Removed 0 Weight Entries.");
                Removed_Zero_Count = gather(sum(Index(:)));
                File_Data_Store(Index,:) = [];
            else
                Removed_Zero_Count = 0;
            end
            %Sort table if enabled
            if(Header.Sort_Events_By_Weight)
                disp("MCPL_To_MAT : Sorting Data by Weight.");
                [File_Data_Store] = sortrows(File_Data_Store, {'Weight', 'Energy', 'X', 'Y', 'Z'}, {'descend', 'ascend', 'ascend', 'ascend', 'ascend'}, 'MissingPlacement', 'first');
            end
            %Ensure the output directory is empty
            if(isfolder(Datastore_Directory_Path))
                disp("MCPL_To_MAT : Datastore directory already exists, clearing directory contents.");
                Attempt_Directory_Deletion(Datastore_Directory_Path);
                Attempt_Directory_Creation(Datastore_Directory_Path);
            end
            disp("MCPL_To_MAT : Performing Datastore Operations and Saving to Datastore Partitions.");
            %Write processed datastore data to files
            write(fullfile(Datastore_Directory_Path, 'Partition_*.mat'), File_Data_Store, 'WriteFcn', @Write_Data);

            %% Merge datastore files
            MAT_File_Path{Read_Index} = MCPL_Merge_Chunks(Datastore_Directory_Path, Header, File_Path, true);
            
            %% Display output file progress
            disp(strcat("MCPL_To_MAT : Input Events    : ", num2str(Header.Particles)));
            disp(strcat("MCPL_To_MAT : Removed Events  : ", num2str(Removed_Zero_Count)));
            
            %% Cleanup temporary files (including all files within)
            Attempt_Directory_Deletion(Temp_Output_File_Root);
        else
            error(strcat("MCPL_To_MAT : MCPL file format not found for file: ", MCPL_File_List(Read_Index).name));
        end
    end
    %% Close parpool
    if(Parpool_Num_Cores > 1)
        Parpool_Delete();
    end
    
    %% Datastore write function (local to parent to save on memory duplication)
    function Write_Data(info, data)
        %Turn table into structure
        data = table2struct(data);
        %Turn vector structure into a scalar structure containing vector data
        data = Structure_Vector_To_Scalar(data);
        data.Datastore_Partition_Information = info;
        %Write data to file
        save(info.SuggestedFilename, '-v7.3', '-struct', 'data');
    end
end

%% Read MCPL Header
function Header = MCPL_Read_Header(File_ID)
    %Read file header
    File_Header = fread(File_ID, 8, '*char');
    %Verify valid MCPL file
    if(strcmpi(File_Header(1), 'M') && strcmpi(File_Header(2), 'C') && strcmpi(File_Header(3), 'P') && strcmpi(File_Header(4), 'L'))
        %Verify file version compatibility
        Format_Version = (File_Header(5)-'0')*100 + (File_Header(6)-'0')*10 + (File_Header(7)-'0');
        if(~any(Format_Version == [2,3]))
            warning(["MCPL_To_MAT : MCPL file version may not be compatible with this read script: ", MCPL_File_List(File_Index).name]);
        end
        %Warning for version 2 files
        if(Format_Version == 2)
            warning(["MCPL_To_MAT : MCPL file version 2 not fully tested for this script, legacy input: ", MCPL_File_List(File_Index).name]);
        end
        %Get computer native endian type
        [~, ~, Computer_Endian] = computer;
        %Check file endian type
        File_Endian_Version = File_Header(8);
        Header.Endian_Switch = false;
        %Compare endianness between the file and computer
        if(strcmpi(File_Endian_Version, 'B'))
            if(strcmpi(Computer_Endian, 'L'))
                Header.Endian_Switch = true;
            end
            Endian.T32 = 'b';
            Endian.T64 = 's';
        elseif(strcmpi(File_Endian_Version, 'L'))
            if(strcmpi(Computer_Endian, 'B'))
                Header.Endian_Switch = true;
            end
            Endian.T32 = 'l';
            Endian.T64 = 'a';
        else
            error(["MCPL_To_MAT : Could not determine endianness for file: ", MCPL_File_List(File_Index).name]);
        end
        Header.Endian = Endian;
        % Cleanup
        clear File_Header Endian_Version;

        %% Start reading remainder of file content
        %% Numeric Content
        %Number of particles
        Header.MCPL_Version = Format_Version;
        clear Format_Version;
        Header.Particles = fread(File_ID, 1, 'uint64', 0, Endian.T64);
        %Number of Comments
        N_Comments = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        %Number of Blobs
        N_Blobs = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        %Optional Header Information
        Header.Opt_Userflag = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        %Header.Opt_Userflag = 0;
        Header.Opt_Polarisation = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        Header.Opt_SinglePrecision = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        Header.Opt_UniversalPDGCode = fread(File_ID, 1, 'int32', 0, Endian.T32);
        Header.Opt_ParticleSize = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        Header.Opt_UniversalWeight = fread(File_ID, 1, 'uint32', 0, Endian.T32);
        if(Header.Opt_UniversalWeight)
            Header.Opt_UniversalWeightValue = fread(File_ID, 1, 'uint64', 0, Endian.T64);
        end
        %Unspecified Use
        Header.Opt_Signature = 0 + 1*Header.Opt_SinglePrecision + 2*Header.Opt_Polarisation + 4*Header.Opt_UniversalPDGCode + 8*Header.Opt_UniversalWeight + 16*Header.Opt_Userflag;

        %% String Content
        % Data Source
        Header.Source{1} = MCPL_Read_String(File_ID, Endian);
        % Comments
        if(N_Comments > 0)
            for Current_Comment = 1:N_Comments
                Header.Comments{Current_Comment} = MCPL_Read_String(File_ID, Endian);
            end
        else
            Header.Comments{1} = '';
        end

        %Blobs
        if(N_Blobs > 0)
            %Blob Keys
            for Current_Blob = 1:N_Blobs
                Header.Blobs.Key{Current_Blob} = MCPL_Read_String(File_ID, Endian);
            end
            %Blob Data
            for Current_Blob = 1:N_Blobs
                Header.Blobs.Data{Current_Blob} = MCPL_Read_String(File_ID, Endian);
                %Transpose the data stored to a readable format
                Header.Blobs.Data{Current_Blob} = Header.Blobs.Data{Current_Blob}';
            end
        else
            Header.Blobs.Key{1} = '';
            Header.Blobs.Data{1} = '';
        end
        Header.Valid = true;
    else
        Header.Valid = false;
    end
    Header.End = ftell(File_ID);
end

%% Read an MCPL String
function MCPL_String = MCPL_Read_String(File_ID, Endian)
    %Get string length
    String_Length = fread(File_ID, 1, 'uint32', 0, Endian.T32);
    %Read string if length is positive
    if(String_Length > 0)
        MCPL_String = fread(File_ID, String_Length, '*char');
    else
        MCPL_String = '';
    end
end

%% Calculates the running relative byte positions of different variables within the binary data
function [Byte_Position, Start_Position, End_Position] = Get_Byte_Position(Byte_Position, Byte_Size)
    %Move to next byte
    Byte_Position = Byte_Position + 1;
    %Output Start position
    Start_Position = Byte_Position;
    %Move to the final byte
    Byte_Position = Byte_Position + Byte_Size - 1;
    %Output End Position
    End_Position = Byte_Position;
end

%% Read and Dump an MCPL File Chunk to MAT file
function MCPL_Dump_Data_Chunk(Header, File_Path, File_Chunk_Index)
    %Get current file chunk
    File_Chunk = Header.File_Chunks(File_Chunk_Index);
    Total_Chunks = length(Header.File_Chunks);
    
    %% Preallocate arrays
    if(Header.Opt_Polarisation)
        Px = zeros(File_Chunk.Events, 1, Header.Byte_Type);
        Py = zeros(File_Chunk.Events, 1, Header.Byte_Type);
        Pz = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    end
    X = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Y = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Z = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Dx = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Dy = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Dz = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Energy = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    Time = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    EKinDir_1 = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    EKinDir_2 = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    EKinDir_3 = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    if(~Header.Opt_UniversalWeight)
        Weight = zeros(File_Chunk.Events, 1, Header.Byte_Type);
    end
    if(Header.Opt_UniversalPDGCode == 0)
        PDGCode = zeros(File_Chunk.Events, 1, 'int32');
    end
    if(Header.Opt_Userflag)
        UserFlag = zeros(File_Chunk.Events, 1, 'uint32');
    end

    %% Read chunk of data from file
    File_ID = fopen(File_Path, 'r');
    %fseek(File_ID, Header.End, 'bof');
    fseek(File_ID, File_Chunk.Start, 'bof');
    if(Header.File_Type == 1)
        File_Data = fread(File_ID, Header.Opt_ParticleSize * File_Chunk.Events, 'uint8=>uint8');
        File_Data = reshape(File_Data, Header.Opt_ParticleSize, size(File_Data, 1) / Header.Opt_ParticleSize);
    elseif(Header.File_Type == 2)
        File_Data = fread(File_ID, (Header.Opt_ParticleSize / Header.Byte_Size) * File_Chunk.Events, 'float64');
        File_Data = reshape(File_Data, Header.Byte_Size, size(File_Data, 1) / Header.Byte_Size);
    else
        error(strcat("MCPL_To_MAT : Chunk ", num2str(File_Chunk.Chunk), " / ", num2str(Total_Chunks), " : Unknown file format"));
    end
    Successful_Chunk_Close = fclose(File_ID);
    if(Successful_Chunk_Close == -1)
        warning(strcat("MCPL_To_MAT : Chunk ", num2str(File_Chunk.Chunk), " / ", num2str(Total_Chunks), " :  Unsuccessful File Close when Reading Data for Chunk: ", num2str(File_Chunk.Chunk)));
    end
    %% Input Handling
    if(Header.File_Type == 1)
        %% MCPL File Read
        %Dynamic_Data_Size = Header.Byte_Size * File_Chunk.Events;
        if(Header.Opt_Polarisation)
            %Px = typecast(reshape(File_Data(Header.Byte_Split.Px.Start:Header.Byte_Split.Px.End,:), Dynamic_Data_Size, 1), Header.Byte_Type);
            Px = typecast(reshape(File_Data(Header.Byte_Split.Px.Start:Header.Byte_Split.Px.End,:), [], 1), Header.Byte_Type);
            Py = typecast(reshape(File_Data(Header.Byte_Split.Py.Start:Header.Byte_Split.Py.End,:), [], 1), Header.Byte_Type);
            Pz = typecast(reshape(File_Data(Header.Byte_Split.Pz.Start:Header.Byte_Split.Pz.End,:), [], 1), Header.Byte_Type);
        end
        X = typecast(reshape(File_Data(Header.Byte_Split.X.Start:Header.Byte_Split.X.End,:), [], 1), Header.Byte_Type);
        Y = typecast(reshape(File_Data(Header.Byte_Split.Y.Start:Header.Byte_Split.Y.End,:), [], 1), Header.Byte_Type);
        Z = typecast(reshape(File_Data(Header.Byte_Split.Z.Start:Header.Byte_Split.Z.End,:), [], 1), Header.Byte_Type);
        EKinDir_1 = typecast(reshape(File_Data(Header.Byte_Split.EKinDir_1.Start:Header.Byte_Split.EKinDir_1.End,:), [], 1), Header.Byte_Type);
        EKinDir_2 = typecast(reshape(File_Data(Header.Byte_Split.EKinDir_2.Start:Header.Byte_Split.EKinDir_2.End,:), [], 1), Header.Byte_Type);
        EKinDir_3 = typecast(reshape(File_Data(Header.Byte_Split.EKinDir_3.Start:Header.Byte_Split.EKinDir_3.End,:), [], 1), Header.Byte_Type);
        Time = typecast(reshape(File_Data(Header.Byte_Split.Time.Start:Header.Byte_Split.Time.End,:), [], 1), Header.Byte_Type);
        if(~Header.Opt_UniversalWeight)
            Weight = typecast(reshape(File_Data(Header.Byte_Split.Weight.Start:Header.Byte_Split.Weight.End,:), [], 1), Header.Byte_Type);
        end
        %Fixed size data
        if(Header.Opt_UniversalPDGCode == 0)
            PDGCode = typecast(reshape(File_Data(Header.Byte_Split.PDGCode.Start:Header.Byte_Split.PDGCode.End,:), [], 1), 'int32');
        end
        if(Header.Opt_Userflag)
            UserFlag = typecast(reshape(File_Data(Header.Byte_Split.UserFlag.Start:Header.Byte_Split.UserFlag.End,:), [], 1), 'uint32');
        end
        %% Adjust endian-ness of byte order (Untested due to development system constraints)
        if(Header.Endian_Switch)
            if(Header.Opt_Polarisation)
                Px = swapbytes(Px);
                Py = swapbytes(Py);
                Pz = swapbytes(Pz);
            end
            X = swapbytes(X);
            Y = swapbytes(Y);
            Z = swapbytes(Z);
            EKinDir_1 = swapbytes(EKinDir_1);
            EKinDir_2 = swapbytes(EKinDir_2);
            EKinDir_3 = swapbytes(EKinDir_3);
            Time = swapbytes(Time);
            if(~Header.Opt_UniversalWeight)
                Weight = swapbytes(Weight);
            end
            %Fixed size data
            if(Header.Opt_UniversalPDGCode == 0)
                PDGCode = swapbytes(PDGCode);
            end
            if(Header.Opt_Userflag)
                UserFlag = swapbytes(UserFlag);
            end
            warning(strcat("MCPL_To_MAT : Chunk ", num2str(File_Chunk.Chunk), " / ", num2str(Total_Chunks), " : Untested Feature, System endianness changed, Verify data using MCPL Tool."));
        end
        % Unpack EKinDir into Dx, Dy, Dz and Energy components
        [Dx, Dy, Dz, Energy] = EKinDir_Unpack(EKinDir_1, EKinDir_2, EKinDir_3, Header.MCPL_Version);
        %% Unit converstions for MCPL files to SI units
        %Convert event energy to KeV from MeV (leaving EKinDir unchanged)
        Energy = Energy ./ 1e-3;
        %Convert cm to m
        X = X ./100;
        Y = Y ./100;
        Z = Z ./100;
    elseif(Header.File_Type == 2)
        %% BXD Data
        X(:) = File_Data(1,:);
        Y(:) = File_Data(2,:);
        Z(:) = File_Data(3,:);
        Dx(:) = File_Data(4,:);
        Dy(:) = File_Data(5,:);
        Dz(:) = File_Data(6,:);
        Weight(:) = File_Data(7,:);
        Energy(:) = File_Data(8,:);
        %Ensure Dx, Dy, Dz are unit vectors
        RMS = sqrt(Dx.^2 + Dy.^2 + Dz.^2);
        disp(strcat("MCPL_To_MAT : Chunk ", num2str(File_Chunk.Chunk), " / ", num2str(Total_Chunks), " : Converting Dx, Dy, Dz into unit vectors. Requirement for MCPL EKinDir packing."));
        Dx = Dx./RMS;
        Dy = Dy./RMS;
        Dz = Dz./RMS;
        % Pack Dx, Dy, Dz into EKinDir
        [EKinDir_1, EKinDir_2, EKinDir_3] = EKinDir_Pack(Dx, Dy, Dz, Energy);
    end

    %% Save file chunk to a temporary file for combination later
    save(File_Chunk.Temp_File_Path, '-v7.3', 'Weight', 'Energy', 'Time', 'X', 'Y', 'Z', 'Dx', 'Dy', 'Dz', 'EKinDir_1', 'EKinDir_2', 'EKinDir_3');
    if(Header.Opt_Polarisation)
        save(File_Chunk.Temp_File_Path, '-append', 'Px', 'Py', 'Pz');
    end
    if(Header.Opt_UniversalPDGCode == 0)
        save(File_Chunk.Temp_File_Path, '-append', 'PDGCode');
    end
    if(Header.Opt_Userflag)
        save(File_Chunk.Temp_File_Path, '-append', 'UserFlag');
    end
end

%% REFERENCE FOR READING GZIP FROM FILESTREAM; UNUSED BUT POTENITAL UPGRADE IN FUTURE
%% https://www.cs.usfca.edu/~parrt/doc/java/JavaIO-notes.pdf
% File_Str = javaObject('java.io.FileInputStream',File_Path);
% inflatedStr = javaObject('java.util.zip.GZIPInputStream', File_Str);
% charStr     = javaObject('java.io.InputStreamReader', inflatedStr);
% lines       = javaObject('java.io.BufferedReader', charStr);
% currentLine = lines.readLine();