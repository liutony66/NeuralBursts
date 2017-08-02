% --- Main GUIDE function - DO NOT EDIT
function varargout = Acquisiv1Andor(varargin)
% User modified matlab generated gui code
% See also: GUIDE, GUIDATA, GUIHANDLES
% Last Modified by GUIDE v2.5 19-Oct-2016 17:53:12

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @AA_OpeningFcn, ...
                       'gui_OutputFcn',  @AA_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);

    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
end
% --- End Main GUIDE function - DO NOT EDIT

%XXX TODO
% fix crash when camera is off / generator is off
% give warning when triggering and the generator channel is off
% saturation (*emgain) (phosphorevent sdk)
% smoothing option in selected roi
%XXX default save trig vid
%XXX default program steps and final
% stop preview before closing shutter in trigger?
% add manual tag to log, and other tags
% XXX fix that stop aquisition resets keep trigger video flag
% add specific rois to plot roi number and plot roi border
% fix auto roi to work with x1 0 magnification
% fix scope not registering stimulation at 0.1 & 0.2v
% change camera capture to 16bit


% --- Executes just before the gui is made visible.
% --- Parameters modified here
function AA_OpeningFcn(hObject, ~, handles, varargin)
%{ Header
% This function has no output args, see OutputFcn.
% varargin   command line arguments to AA (see VARARGIN)
% Choose default command line output for AA
%}

    % Add the main figure handle to the handles struct
    handles.output = hObject;
    guidata(hObject, handles);

    % define global variables
    global tic_time;               % time of main timer init
    global output_dir;             % default directory for output files
    global root_file_name;         % root name for output files
    global log_file_handle;        % handle to log file
    global matlab_precision_bug;   % problem with matlab comparisons (0.1 + 1.1 ~= 1.2)

    global maskROI;                % cell array of defined ROI masks
    global x_pos;                  % info for drawing rois
    global y_pos;                  % info for drawing rois

    global adj_contrast;   
    global frozen_ylim;            % frozen YLim for selected ROI plot
    global manual_ylim;            % manual YLim for selected ROI plot
    global plot_width;             % width of data plots (in sec)
    global roi_bunch_size;         % number of ROIs to select when selecting a bunch
    
    global gFlags;                 % global control flags struct
    global gFunctionGenerator;     % global function generator struct
    global gScope;                 % global oscilloscope struct
    global gAndor;                 % global camera struct
    global gVideo;                 % global video struct
    global gTrigger;               % global trigger struct
    global gShutter;               % global shutter serial connection handle


    %-------------------------------
    % Modifiable Parameters
    %-------------------------------
    
    % General settings
    output_dir           = 'D:\DATA\Eyal\'; % initial directory for output files
    gVideo.reserved_mem  = 3e9;             % number of unused B of mem required to prevent paging (determined empirically for a given system)
    plot_width           = 60;              % width of data plots (in sec)
    roi_bunch_size       = 10;              % number of ROIs to select when selecting a bunch
        
    % Function generator initial settings
    gFunctionGenerator.Frequency     = 500;         % frequency (KHz)            (0.001mHz - 10MHz)     - base frequency of the stimulation
    gFunctionGenerator.Amplitude     = 0.1;         % voltage (Vp-p)             (0.01V-10V)            - amplitude of the stimulation
    gFunctionGenerator.BurstCount    = 20;          % number of cycles per burst (2-999999)             - number of cycles in a pulse
    gFunctionGenerator.TriggerMode   = 'BURS';      % trigger mode               (CONT/TRIG/GATE/BURS)
    gFunctionGenerator.Function      = 'SIN';       % function shape             (SIN/SQU/TRI/ARB/PULS) 
    gFunctionGenerator.TriggerSource = 'EXT';       % trigger source             (MAN/INT/EXT/BUS)

    gFunctionGenerator.Ch2_TriggerMode   = 'TRIG';  % trigger mode               (CONT/TRIG/GATE/BURS)  - for a single pulse this should be TRIG, for multiple pulses BURS
    gFunctionGenerator.Ch2_BurstCount    = 2;       % number of cycles per burst (2-999999)             - if using multiple pulses, the number of pulses
    gFunctionGenerator.Ch2_Frequency     = 1;       % frequency (KHz)            (0.001mHz - 10MHz)     - pulse repetition frequency
    gFunctionGenerator.Ch2_Amplitude     = 10;      % ch2 voltage (Vp-p)         (0.01V-10V)            - trigger level (+-5)
    gFunctionGenerator.Ch2_Function      = 'SQU';   % function shape             (SIN/SQU/TRI/ARB/PULS) 
    gFunctionGenerator.Ch2_TriggerSource = 'MAN';   % trigger source             (MAN/INT/EXT/BUS)   
    
    % Oscilloscope settings
    gScope.voltage_ch    = 1;                   % channel used to measure amplifier output voltage
    gScope.current_ch    = 2;                   % channel used to measure current clamp output voltage
    gScope.voltage_scale = 0.500;               % initial vertical scale of amplifier output voltage (V)
    gScope.current_scale = 0.005;               % initial vertical scale of current clamp output voltage (V)
    gScope.horiz_scale   = 5e-7;                % horizontal scale (s)
    gScope.trig_delay    = 20e-6;               % trigger to aquisition delay (s)
    gScope.trig_level    = 0.130;               % trigger threshold (V)
    gScope.trig_source   = gScope.voltage_ch;   % trigger source channel
    
    % Camera settings (more advanced settings are in the camera initialization function)
    gAndor.ExposureTime   = 0.1;    % exposure time setting (in s). zero will result in minimum possible exposure time
    gAndor.xbin           = 1;      % horizontal binning setting
    gAndor.ybin           = 1;      % vertical binning setting
    gAndor.EMGain         = 0;      % initial emgain level
    gAndor.EMGainAdvanced = 0;      % should emgain levels above 300 be possible (boolean). this should probably be off (0)
    gAndor.preAmp         = 2;      % preamp level (0-2) 
    gAndor.setTemp        = -90;    % target camera temperature [-90]
    
    % trigger settings
    gTrigger.trigger_loop_delay    = 1500;                           % initial trigger loop delay (in seconds)
    gTrigger.prog_volt_step        = 0.01;                           % initial automated voltage step (V)
    gTrigger.prog_volt_final       = 3;                              % initial automated voltage final value (V)
    gTrigger.prog_volt_target_reps = 1;                              % initial automated voltage repeats at each voltage
    
    gTrigger.video_pre_trigger    = 5;                               % seconds of video to save before trigger
    gTrigger.video_post_trigger   = 10;                              % seconds of video to save after trigger
    gTrigger.shutter_pre_trigger  = gTrigger.video_pre_trigger  + 10; % seconds before trigger to activate shutter %XXX increased for GCAMP stability
    gTrigger.shutter_post_trigger = gTrigger.video_post_trigger + 1; % seconds after trigger to deactivate shutter
    gTrigger.plot_trig_width      = 0.1;                             % plot trigger width in seconds
    
    %-------------------------------
    % End Modifiable Parameters
    %-------------------------------
    
    % initialize vars
    tic;                                                % start the main timer
    tic_time = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');  % save the time of the main timer init
    
    addpath(pwd);                                                                                            % preserve the m file directory in the path
    set(handles.RootFileNameText, 'String', output_dir);                                                     % set the output file textbox
    set(handles.SetTempText,      'String', num2str(gAndor.setTemp));                                        % set target temperature textbox
    set(handles.TriggerLoopBox,   'String', ['Trigger Every ',num2str(gTrigger.trigger_loop_delay),' sec']); % set trigger loop delay text
    set(handles.ProgVoltStepText, 'String', num2str(gTrigger.prog_volt_step));                               % set automated voltage step text
    set(handles.ProgVoltFinalText,'String', num2str(gTrigger.prog_volt_final));                              % set automated voltage final value text
    set(handles.ProgVoltRepsText, 'String', num2str(gTrigger.prog_volt_target_reps));                        % set automated repeats at each voltage text
    
    root_file_name                    = [];     % init root name for output files
    log_file_handle                   = -1;     % init log file handle
    matlab_precision_bug              = 1e-15;  % set matlab precision bug buffer

    gFlags.out_files_enabled          = false;  % output to log and data files disabled
    gFlags.preview_enabled            = false;  % video preview disabled
    gFlags.data_aquisition_enabled    = false;  % ROI data aquisition disabled    
    gFlags.save_data_enabled          = false;  % ROI data recording to file disabled
    gFlags.save_video_enabled         = false;  % saving video to file disabled    
    
    gVideo.vid_struct                 = [];     % init video frame buffer

    gFunctionGenerator.handle         = [];     % init function generator handle
    gScope.handle                     = [];     % init oscilloscope handle
    gShutter.handle                   = [];     % init shutter handle
    gTrigger.triggered_flag           = false;  % init trigger flag
    gTrigger.trigger_loop_flag        = false;  % init triger loop flag
    gTrigger.trigger_times            = [];     % init trigger times
    gTrigger.trigger_loop_timer       = [];     % init trigger loop timer
    gTrigger.video_pre_timer          = [];     % init video pre timer
    gTrigger.video_post_timer         = [];     % init video post timer
    gTrigger.prog_volt_flag           = false;  % init program voltage flag
    gTrigger.prog_volt_curr_reps      = 0;      % init program voltage current repeat count
    gTrigger.prog_volt_step           = [];     % init program voltage step
    gTrigger.prog_volt_final          = [];     % init program voltage final voltage
    gTrigger.prog_volt_target_reps    = [];     % init program voltage target repeat count
    gTrigger.prog_volt_sequence       = [];     % init program voltage sequence
    gTrigger.control_shutter_flag     = false;  % init shutter control flag
    gTrigger.shutter_pre_timer        = [];     % init shutter pre timer
    gTrigger.shutter_post_timer       = [];     % init shutter post timer
    gTrigger.save_trigger_video_flag  = false;  % init saving trigger video flag
    gTrigger.use_scope_flag           = false;  % init scope measurement of amp output flag

    maskROI                           = [];     % init ROI mask cell aray
    x_pos                             = [];     % init roi drawing info
    y_pos                             = [];     % init roi drawing info

    adj_contrast                      = [0.0 1.0]';
    frozen_ylim                       = [0,1];  % init frozen YLim for selected ROI plot
    manual_ylim                       = [0,1];  % init manual YLim for selected ROI plot

    % initialize shutter control serial connection
    InitShutterPort();
    
    % initialize the camera
    InitializeAndorCamera(handles);
end

% --- Executes when user clicks on the windows X button.
function figure1_CloseRequestFcn(hObject, ~, handles)
    global gFunctionGenerator;      % global function generator struct
    global gFlags;                  % global control flags struct
    global gScope;                  % global oscilloscope struct
    global gShutter;                % global shutter serial connection handle

    gFlags.preview_enabled = false; % disable video preview

    timers = timerfind;
    delete(timers);

        
    % close shutter and shutter port
    ShutterOffButton_Callback([], [], handles);     % close the shutter
    fclose(gShutter.handle);                        % close shutter serial object
    
    % close scope port
    if ~isempty(gScope.handle)
        fclose(gScope.handle);
    end
    
    % close function generator port
    if ~isempty(gFunctionGenerator.handle)
        fclose(gFunctionGenerator.handle);
    end
    
    fclose('all');
    
    % stop any running aquisitions
    [ret.AbortAcquisition] = AbortAcquisition;
    disp(['ret.AbortAcquisition = ',num2str(ret.AbortAcquisition)]);
    
    % turn off the cooling system
    [ret.CoolerOFF] = CoolerOFF;
    disp(['ret.CoolerOFF = ',num2str(ret.CoolerOFF)]);
    
    % make sure the temp is over -20 before shutting down
    [ret.GetTemperature,measured_temp] = GetTemperature;
    if measured_temp <= -20
        disp('shutting down the camera while it is < -20° may cause damage');
        temperror_reply = questdlg('shutting down the camera while it is < -20° may cause damage','','wait','close','wait');
        if ~strcmp(temperror_reply,'close')
            while measured_temp <= -20
                pause(1);
                [ret.GetTemperature,measured_temp] = GetTemperature;
                disp(['temperature: ',num2str(measured_temp),'°']);
            end
        end
    end
    
    [ret.AndorShutDown] = AndorShutDown;
    disp(['ret.AndorShutDown = ',num2str(ret.AndorShutDown)]);

    delete(hObject);
    close all;
end

%--------------------------------------------------------------------------
% Capture and Video Functions
%--------------------------------------------------------------------------

% main looping function - gets the images from the camera and processes them
function StartPreviewButton_Callback(~, ~, handles)                         %#ok<DEFNU>

    % define glocal variables
    global acq_start_last_time;     % time of last acquisition start

    global maskROI;                 % cell array of ROI masks
    global data_file_fid;           % intensity data file handle
    global frozen_ylim;             % frozen YLim for selected ROI plot
    global manual_ylim;             % manual YLim for selected ROI plot
    global plot_width;              % width of data plots (in sec)
    
    global adj_contrast;
    global images;

    global x_pos;
    global y_pos;

    global prev_img_idx;
    
    global gFlags;                 % global control flags struct
    global gAndor;                 % global camera struct
    global gVideo;                 % global video struct
    global gTrigger;               % global trigger struct
    
    % disable start preview button (will be reenabled at the end)
    set(handles.StartPreviewButton,'Enable','off');
    
    % calculate video buffer size
    CalcVideoBuffer(handles);
    
    % set video preview flag to started
    gFlags.preview_enabled = true;     % flag that the preview is enabled

    % log start preview
    if gFlags.out_files_enabled
        LogEvent('StartPreview');
    end
    
    % get colororder
    color_order = get(gca,'ColorOrder');
    
    % create image object
    image(zeros(gAndor.imHeight, gAndor.imWidth, 1),'Parent',handles.axes_image);
    figSize = get(handles.figure1,'Position');
    figWidth = figSize(3);
    figHeight = figSize(4);
    set(handles.axes_image,'unit','pixels','position',[ figWidth*4.95-gAndor.imWidth figHeight*12.75-gAndor.imHeight gAndor.imWidth gAndor.imHeight ]); %12.75

    % start acquisition and get the start time
    pre_acq_start_time = toc;   
    [ret.StartAcquisition]=StartAcquisition;     % start acquisition from andor
    post_acq_start_time = toc;
    acq_start_last_time = mean([pre_acq_start_time,post_acq_start_time]);

    j = 1;
    timewindow = floor(plot_width / gAndor.validKinTime);
    prev_img_idx = 0;

    while gFlags.preview_enabled

        % check if there are new images to process
        [ret.GetNumberNewImages,first_img_idx,last_img_idx] = GetNumberNewImages;  % get the new image indexes
        if (first_img_idx > prev_img_idx)
            prev_img_idx   = first_img_idx;
            frame_numbers  = first_img_idx:last_img_idx;
            num_got_images = size(frame_numbers,2);

            % check camera buffer capacity
            if num_got_images > (gAndor.cam_buffer_size * 0.8)              % if the buffer is over 80% full
                disp('error - camera buffer reaching capacity');
                
                if gFlags.out_files_enabled                                 % if output to files is enabled
                    LogEvent('error - Camera Buffer Reaching Capacity');    % log buffer reacing capacity
                end
            end

            % get images from camera
            [ret.GetImages,images_raw,~,~] = GetImages16(first_img_idx,last_img_idx,gAndor.imWidth*gAndor.imHeight*num_got_images);
            
            images = reshape(images_raw,gAndor.imWidth,gAndor.imHeight,1,num_got_images);

            % show first image
            adjusted_img = imadjust( cast(images(:,:,1,num_got_images),'uint16'),[adj_contrast(1) adj_contrast(2)],[ ]);
            imshow(adjusted_img,'Parent',handles.axes_image);
            hold on;
            
            % draw ROI boundries
            if get(handles.ShowRoiBoundryCheckbox,'Value');                 % if the show ROI boundries checkbox is selected
                plot(x_pos,y_pos,'-','linewidth',1,'Parent',handles.axes_image);
            end
            
            % draw ROI numbers
            if get(handles.ShowRoiNumCheckbox,'Value');                     % if the show ROI numbers checkbox is selected
                for curr_ROI = 1:length(maskROI)
                    [roi_corner.y,roi_corner.x] = find(maskROI{curr_ROI},1,'first');
                    text(roi_corner.x+1,roi_corner.y+4,num2str(curr_ROI),'Color',color_order(1+mod(curr_ROI-1,length(color_order)),:),'FontSize',7,'BackgroundColor','w');
                end
            end
            hold off;

            % process image data
            if gFlags.data_aquisition_enabled
                Ave_intensity(j:j+num_got_images-1,1:length(maskROI)) = 0;                      % prealocate intensity data mat
                
                for k = 1:num_got_images
                    img = images(:,:,1,k);
                    frame_times(j+k-1) = (frame_numbers(k) * gAndor.validKinTime) + acq_start_last_time;
                    for cur_ROI=1:length(maskROI)
                        Ave_intensity(j+k-1,cur_ROI) = mean(img(logical(maskROI{cur_ROI})));   % calculate the intensities of the ROIs
                    end
                end
                
                % calculate plotting timewindow
                begin_frame = max(j-timewindow,1); 
                visible_frames = (begin_frame:j+num_got_images-1);
                visible_times = frame_times(visible_frames);

                % plot all ROI data
                visible_intensity = Ave_intensity(visible_frames,:);                % crashes if no ROI defined prior to this point                
                visible_intensity(visible_intensity == 0) = NaN;           
                if ~gFlags.preview_enabled; break; end;                             % make sure the loop is not running after the GUI has already been closed

                if get(handles.PlotAllROIsBox,'Value');                             % if the show all ROIs checkbox is selected
                    % plot mean value for all ROIs
                    plot(handles.Avg_Intensity,visible_times,visible_intensity);

                    % plot trigger data for all ROIs     
                    curr_ylim  = ylim(handles.Avg_Intensity);
                    y_min = curr_ylim(1);
                    y_max = curr_ylim(2);
                    for curr_trig_time = gTrigger.trigger_times(gTrigger.trigger_times >= visible_times(1))
                        x_min = curr_trig_time;
                        x_max = curr_trig_time + gTrigger.plot_trig_width;
                        patch([x_min,x_max,x_max,x_min],[y_min+1e-3,y_min+1e-3,y_max,y_max],-eps*ones(1,4),[.8 .8 1],'EdgeColor',[.8 .8 1],'Parent',handles.Avg_Intensity);
                    end
                end
                
                % plot selected ROI data
                if get(handles.PlotSelectedROIsBox,'Value');           % if the plot checkbox is selected
                    chosen_rois = get(handles.roi_list,'Value');
                    

                    if ~isempty(chosen_rois)
                        % plot mean value for selected ROIs
                        set(handles.axes_left, 'ColorOrder', color_order(1+mod(chosen_rois-1,length(color_order)),:));
                        set(handles.axes_left,'NextPlot','replacechildren')
                        plot(handles.axes_left,visible_times,visible_intensity(:,chosen_rois));
                        hold(handles.axes_left,'on');

                        % plot trigger data for selected ROIs
                        curr_ylim  = ylim(handles.axes_left);
                        y_min = curr_ylim(1);
                        y_max = curr_ylim(2);
                        for curr_trig_time = gTrigger.trigger_times(gTrigger.trigger_times >= visible_times(1))
                            x_min = curr_trig_time;
                            x_max = curr_trig_time + gTrigger.plot_trig_width;
                            patch([x_min,x_max,x_max,x_min],[y_min+1e-3,y_min+1e-3,y_max,y_max],-eps*ones(1,4),[.8 .8 1],'EdgeColor',[.8 .8 1],'Parent',handles.axes_left);
                        end

                        hold(handles.axes_left,'off');

                        % freeze YLim if selected
                        if     get(handles.FreezeYlimBox,'Value')
                            ylim(handles.axes_left,frozen_ylim);
                        % manual YLim if selected
                        elseif get(handles.ManualYlimBox,'Value')
                            ylim(handles.axes_left,manual_ylim);
                        else
                            ylim(handles.axes_left,'auto');
                        end
                    end
                end

                % save data to file 
                if (gFlags.save_data_enabled)
                    % add frame and time stamp to the data
                    file_frame_numbers = first_img_idx:last_img_idx;
                    file_frame_times = ((file_frame_numbers * gAndor.validKinTime) + acq_start_last_time);
                    temp_data = [file_frame_numbers',file_frame_times',Ave_intensity((j:j+num_got_images-1),:)];

                    % output ROI intensity data to file     
                    fprintf(data_file_fid,[repmat(' %f', 1, size(temp_data, 2)), '\n'], temp_data.');

                    % save video
                    if gFlags.save_video_enabled 
                        for frame_idx = 1:size(images,4)
                            frame_name = ['t', strrep(num2str(file_frame_times(frame_idx)),'.','_')];        % set the variable name to the frame time
                            gVideo.vid_struct.(frame_name).image = images(:,:,:,frame_idx);                  % insert the frame into the struct
                            gVideo.vid_struct.(frame_name).time  = file_frame_times(frame_idx);              % insert the frame time into the struct

                            gVideo.remaining_vid_secs = gVideo.remaining_vid_secs - gAndor.validKinTime;     % calc the number of sec left in the vid buffer
                            set(handles.VidSecsLeftText,'String',num2str(gVideo.remaining_vid_secs,'%.0f')); % update the number of sec left in the vid buffer in the gui
                        end
                    end
                end            

                gTrigger.triggered_flag = 0;
                j=j+num_got_images;            
            end
        end  
        drawnow;                                          % important to make sure the function is interruptible            
    end

    [ret.AbortAcquisition] = AbortAcquisition;          % stop acquisition from andor
    disp(['ret.AbortAcquisition = ',num2str(ret.AbortAcquisition)]);

    if ~ishandle(handles.figure1)                       % indicates the entire program is closing
        close all;
    else                                                % indicates the video preview is closing but not the entire program
        set(handles.StartPreviewButton,'Enable','on');  % enable start preview button (was disabled at the begining)
        gFlags.preview_enabled = false;                 % flag that the preview is disabled
    end
end
   
function StopPreviewButton_Callback(~, ~, handles)                          %#ok<INUSD,DEFNU>
    global gFlags;                  % global control flags struct

    gFlags.preview_enabled = false; % disable video preview

    if gFlags.out_files_enabled
        LogEvent('StopPreview');
    end
end

function CloseButton_Callback(~, ~, handles)                                %#ok<DEFNU>
    figure1_CloseRequestFcn(handles.figure1,[],handles);
end

function StartAcquisitionSaveButton_Callback(~, ~, handles)                 %#ok<DEFNU>
    global root_file_name;      % root name for output files
    global data_file_fid;   	% handle to intensity data output file
    global maskROI;             % cell array of defined ROI masks

    global gFlags;              % global control flags struct
    global gAndor;              % global camera struct

    if ~gFlags.out_files_enabled
        disp('error - output files are not enabled');
        warndlg('error - output files are not enabled');
    else
        if length(maskROI) < 1
            disp('error - can not start acquisition without any ROIs, creating default roi');
            AddRectRoiButton_Callback([],[],handles,[1,1,gAndor.imWidth,gAndor.imHeight]);
        end
        
        gFlags.data_aquisition_enabled = true;  % enable data acquisition
        gFlags.save_data_enabled       = true;  % enable data recording to file

        data_file_name = [root_file_name,'.data'];
        data_file_fid = fopen(data_file_name,'at')                           %#ok<NOPRT>

        set(handles.KeepVideoCheckbox,'Enable','on');       % enable the manual save video checkbox
        set(handles.SaveTriggerVideoBox,'Enable','on');     % enable the trigger save video checkbox

        LogEvent('StartAcquisitionSave');
    end
end

function StartAcquisitionNoSaveButton_Callback(~, ~, handles)               %#ok<DEFNU>
    global maskROI;             % cell array of defined ROI masks

    global gFlags;              % global control flags struct
    global gAndor;              % global camera struct

    if length(maskROI) < 1
        disp('error - can not start acquisition without any ROIs, creating default roi');
        AddRectRoiButton_Callback([],[],handles,[1,1,gAndor.imWidth,gAndor.imHeight]);
    end
    
    if gFlags.save_data_enabled   % if save aquisition is running
        StopAcquisitionButton_Callback(handles.StopAcquisitionButton,[],handles) % stop the running aquisition
    end

    gFlags.data_aquisition_enabled = true;  % enable ROI data acquisition
    gFlags.save_data_enabled       = false; % disable ROI data recording to file
end

function StopAcquisitionButton_Callback(~, ~, handles)
    global data_file_fid;
    global gFlags;                 % global control flags struct
    global gTrigger;               % global trigger struct

    % turn off manual video saving
    set(handles.KeepVideoCheckbox,'Enable','off');      % disable the manual save video checkbox
    if gFlags.save_video_enabled
        set(handles.KeepVideoCheckbox,'Value',0);       % uncheck the manual save video checkbox
        KeepVideoCheckbox_Callback([],[], handles);     % stop manually saving video
    end
    
    % turn off trigger video saving
    set(handles.SaveTriggerVideoBox,'Enable','off');    % disable the save trigger video checkbox
    if gTrigger.save_trigger_video_flag
        set(handles.SaveTriggerVideoBox,'Value',0);     % uncheck the save trigger video checkbox
        SaveTriggerVideoBox_Callback([],[], handles);   % stop saving trigger video
    end

    % disable data aquisition
    gFlags.data_aquisition_enabled  = false;    % ROI data aquisition disabled
    if (gFlags.save_data_enabled)
        fclose(data_file_fid);
    end
    gFlags.save_data_enabled        = false;    % ROI data recording to file disabled

    if gFlags.out_files_enabled
        LogEvent('StopAcquisition');
    end
end

function ContrastAdjustButton_Callback(~, ~, handles)                       %#ok<INUSD>
    global adj_contrast;
    global images;

    adj_contrast=stretchlim(cast(images(:,:,:,1),'uint16'));
end

function CalcVideoBuffer(handles)
    global gVideo;  % global video struct
    global gAndor;  % global camera struct
    
    % calculate usable memory for video
    [~,mem_struct] = memory;                              % get mem info
    %physical_mem   = mem_struct.PhysicalMemory.Total;    % get physical mem size XXX
    %useable_mem    = physical_mem - gVideo.reserved_mem; % calc number of useable B of physical mem XXX
    
    available_mem   = mem_struct.PhysicalMemory.Available; % get available mem size XXX
    useable_mem     = available_mem - gVideo.reserved_mem; % calc number of useable B of available mem XXX
    

    % calculate maximal video buffer size
    pixel_size     = 2;                                                                     % each int16 pixel takes up 2B of mem
    frame_overhead = 200;                                                                   % 200B of overhead required per frame
    frame_size     = ((gAndor.imWidth * gAndor.imHeight * pixel_size) + frame_overhead);    % calc mem size of the entire frame
    max_vid_frames = useable_mem / frame_size;                                              % calc max frames storable in useable mem
    gVideo.max_vid_secs   = max_vid_frames * gAndor.validKinTime;                           % calc max vid time storable in useable mem
    gVideo.remaining_vid_secs = gVideo.max_vid_secs;                                        % init the number of sec left in the vid buffer
    set(handles.VidSecsLeftText,'String',num2str(gVideo.remaining_vid_secs,'%.0f'));        % update the number of sec left in the vid buffer in the gui   
end

function KeepVideoCheckbox_Callback(~, ~, handles)
    global root_file_name;      % root name for output files
    global vid_file_root_name;  % root name of video output file

    global gFlags;              % global control flags struct
    global gVideo;              % global video struct

    vid_file_root_name = [root_file_name,'.vid'];   % name of video output file
   
    if get(handles.KeepVideoCheckbox,'Value')       % if the checkbox is checked    
        gFlags.save_video_enabled = true;                   % enable saving video to file
        LogEvent('Video - Keep Video Enabled');     
        
        set(handles.FlushVidBufferButton,'Enable','off');           % disable flush buffer button
        set(handles.SaveVidBufferButton,'Enable','off');            % disable save buffer button
        set(handles.SavePartialVidBufferButton,'Enable','off');     % disable save partial buffer button
    else                                            % if the checkbox is unchecked
        gFlags.save_video_enabled = false;                  % disable saving video to file
        LogEvent('Video - Keep Video Disabled');

        % if video data has been aquired
        if ~isempty(gVideo.vid_struct)
            set(handles.FlushVidBufferButton,'Enable','on');        % enable flush buffer button
            set(handles.SaveVidBufferButton,'Enable','on');         % enable save buffer button
            set(handles.SavePartialVidBufferButton,'Enable','on');  % enable save partial buffer button
        end
    end
end

function FlushVidBufferButton_Callback(~, ~, handles)                       %#ok<DEFNU>
    global gFlags;                    % global control flags struct
    global gVideo;                    % global video struct

    % clean the buffer
    gVideo.vid_struct = [];

    % log video flush event
    if gFlags.out_files_enabled       % if output to files is enabled
        LogEvent('Video - Flushed');  % log video save event
    end

    % update the number of seconds left in the vid buffer
    gVideo.remaining_vid_secs = gVideo.max_vid_secs;
    set(handles.VidSecsLeftText,'String',num2str(gVideo.remaining_vid_secs,'%.0f'));  % update the gui

    set(handles.FlushVidBufferButton,'Enable','off');           % disable flush buffer button
    set(handles.SaveVidBufferButton,'Enable','off');            % disable save buffer button
    set(handles.SavePartialVidBufferButton,'Enable','off');     % disable save partial buffer button
end

function SaveVidBufferButton_Callback(~, ~, handles)
    global vid_file_root_name;      % name of video output file

    global gFlags;                  % global control flags struct
    global gVideo;                  % global video struct

    % find available video filename suffix
    vid_file_suffix = 1;
    vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix)];
    while exist([vid_file_name,'.mat'],'file') == 2
        vid_file_suffix = vid_file_suffix + 1;
        vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix)];
    end

    % save the frames to file and clean the buffer XXX find a way to save big files without compression
    vidvar_details = whos('gVideo');
    if vidvar_details.bytes < 1.9e9
        % if video is <2GB we can save it without compression (faster)
        vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix)];
        save([vid_file_name,'.mat'],'-struct','gVideo','-v6');
    else
        % if video is >2GB we have to split it
        chunk_num = ceil(vidvar_details.bytes / 1.9e9); % get the number of files to split to
        
        frame_list            = fieldnames(gVideo.vid_struct);
        frames_per_chunk      = ceil(length(frame_list) / chunk_num);
        frames_per_last_chunk = length(frame_list) - ((chunk_num - 1) * frames_per_chunk);
        
        next_frame_id = 1;
        
        for curr_chunk = 1:chunk_num
            if curr_chunk < chunk_num
                last_frame_id = next_frame_id + frames_per_chunk - 1;
            else
                last_frame_id = next_frame_id + frames_per_last_chunk - 1;
            end
            
            for curr_frame_id = next_frame_id:last_frame_id
                frame_name = frame_list{curr_frame_id};
                chunk.vid_struct.(frame_name) = gVideo.vid_struct.(frame_name);
            end
            next_frame_id = next_frame_id + frames_per_chunk;
            
            vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix + curr_chunk - 1)];
            save([vid_file_name,'.mat'],'-struct','chunk','-v6');
            chunk = [];
        end
    end
        
    gVideo.vid_struct = [];

    % log video save event
    if gFlags.out_files_enabled                         % if output to files is enabled
        LogEvent(['Video - Saved to ',vid_file_name]);  % log video save event
    end

    % update the number of seconds left in the vid buffer
    gVideo.remaining_vid_secs = gVideo.max_vid_secs;
    set(handles.VidSecsLeftText,'String',num2str(gVideo.remaining_vid_secs,'%.0f'));  % update the gui

    set(handles.FlushVidBufferButton,'Enable','off');           % disable flush buffer button
    set(handles.SaveVidBufferButton,'Enable','off');            % disable save buffer button
    set(handles.SavePartialVidBufferButton,'Enable','off');     % disable save partial buffer button
end

function SavePartialVidBufferButton_Callback(~, ~, handles)                 %#ok<DEFNU>
    global vid_file_root_name;      % name of video output file

    global gFlags;                  % global control flags struct
    global gVideo;                  % global video struct

    % check number of video seconds to save
    vid_sec_to_save = str2double(get(handles.VidSecsToSaveText,'String'));
    if isnan(vid_sec_to_save)
        disp('error - number of video seconds to save not defined');
        warndlg('error - number of video seconds to save not defined');
    else
        % get older frame names to remove
        frame_names_cell = fieldnames(gVideo.vid_struct);
        for curr_frame_idx = 1:length(frame_names_cell)
            frame_times_vec(curr_frame_idx) = gVideo.vid_struct.(frame_names_cell{curr_frame_idx}).time;
        end
        frame_names_to_remove_cell = frame_names_cell(frame_times_vec < (max(frame_times_vec) - vid_sec_to_save));
        
        % remove all older frames
        gVideo.vid_struct = rmfield(gVideo.vid_struct,frame_names_to_remove_cell);
        
        % find available video filename
        vid_file_suffix = 1;
        vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix)];
        while exist([vid_file_name,'.mat'],'file') == 2
            vid_file_suffix = vid_file_suffix + 1;
            vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix)];
        end

        % save the frames to file and clean the buffer
        save([vid_file_name,'.mat'],'-struct','gVideo','-v6');
        gVideo.vid_struct = [];

        % log video save event
        if gFlags.out_files_enabled                         % if output to files is enabled
            LogEvent(['Video - Saved to ',vid_file_name]);  % log video save event
        end

        % update the number of seconds left in the vid buffer
        gVideo.remaining_vid_secs = gVideo.max_vid_secs;
        set(handles.VidSecsLeftText,'String',num2str(gVideo.remaining_vid_secs,'%.0f'));  % update the gui

        set(handles.FlushVidBufferButton,'Enable','off');           % disable flush buffer button
        set(handles.SaveVidBufferButton,'Enable','off');            % disable save buffer button
        set(handles.SavePartialVidBufferButton,'Enable','off');     % disable save partial buffer button
    end
end

%--------------------------------------------------------------------------
% ROI Functions
%--------------------------------------------------------------------------

% save ROI masks to file
function SaveROIs
    global root_file_name;          % root name for output files
    global maskROI;                 % mat of ROI masks

    file_name = [root_file_name,'.rois.mat'];

    var_name = ['t', strrep(num2str(toc),'.','_')]; % set the variable name to the current time
    roi_struct.(var_name) = maskROI;                %#ok<STRNU> % insert the roi masks into a struct
    if exist(file_name,'file') == 2                 % save the roi masks to file under the current time
        save(file_name,'-struct','roi_struct','-append');
    else
        save(file_name,'-struct','roi_struct');
    end
    roi_struct = [];                                                        %#ok<NASGU>
end

% update the contents of the ROI list
function UpdateRoiList(handles)
    global maskROI;                % cell array of defined ROI masks

    if isempty(maskROI)
       new_roi_list_string = [];
       new_roi_list_value  = [];
    else
        for curr_roi = 1:length(maskROI)
            new_roi_list_string{curr_roi} = curr_roi;
        end

        old_roi_list_value  = get(handles.roi_list,'Value');
        if max(old_roi_list_value) > length(maskROI)
            new_roi_list_value  = [];
        else
            new_roi_list_value = old_roi_list_value;
        end
    end

    set(handles.roi_list,'Value',new_roi_list_value);
    set(handles.roi_list,'String',new_roi_list_string);
end

function AddRectRoiButton_Callback(~, ~, handles, varargin)
    global maskROI;                 % mat of ROI masks

    global x_pos;
    global y_pos;

    global gFlags;                  % global control flags struct

    max_length=8;
    
    if isempty(varargin)            % function called without coordinates
        h1 = imrect(handles.axes_image);
        roi_pos = wait(h1);
    else                            % function called with coordinates
        roi_pos = varargin{1};
        h1 = imrect(handles.axes_image,roi_pos);
    end

    disp(roi_pos);
    xx_pos=[roi_pos(1) roi_pos(1) roi_pos(1)+roi_pos(3) roi_pos(1)+roi_pos(3)];
    yy_pos=[roi_pos(2) roi_pos(2)+roi_pos(4) roi_pos(2)+roi_pos(4) roi_pos(2)];
    current_len=length(xx_pos);
    numROI = length(maskROI) + 1;

    for i=1:max_length
        indx=mod(i,current_len);
        if (~indx)
            indx=indx+current_len;
        end
        x_pos(i,numROI)=xx_pos(indx);
        y_pos(i,numROI)=yy_pos(indx);
    end
    BW = createMask(h1);
    maskROI{numROI} = sparse(BW);

    if gFlags.out_files_enabled               % if output to files is enabled
        LogEvent('ROI - Rectangle Added');  % log ROI change
        SaveROIs;                           % save ROIs to file
    end

    UpdateRoiList(handles);
end

function AddPointRoiButton_Callback(~, ~, handles, varargin)
    global maskROI;                 % mat of ROI masks
    global gAndor;                  % global camera struct

    global x_pos;
    global y_pos;

    global gFlags;                  % global control flags struct

    max_length=8;
    
    if isempty(varargin)            % function called without coordinates
        h1=impoint(handles.axes_image);
        roi_pos=getPosition(h1);
    else                            % function called with coordinates
        roi_pos = varargin{1};
    end
    
    xx_pos=[roi_pos(1)-5 roi_pos(1)-5 roi_pos(1)+5 roi_pos(1)+5];
    yy_pos=[roi_pos(2)-5 roi_pos(2)+5 roi_pos(2)+5 roi_pos(2)-5];

    BW = roipoly(gAndor.imHeight,gAndor.imWidth,xx_pos,yy_pos);
    numROI = length(maskROI) + 1;
    for k=1:max_length
        indx=mod(k,4);
        if (~indx)
            indx=indx+4;
        end
        x_pos(k,numROI)=xx_pos(indx);
        y_pos(k,numROI)=yy_pos(indx);
    end
    maskROI{numROI} = sparse(BW);

    if gFlags.out_files_enabled         % if output to files is enabled
        LogEvent('ROI - Point Added');  % log ROI change
        SaveROIs;                       % save ROIs to file
    end

    UpdateRoiList(handles);
end

function DeleteRoiButton_Callback(~, ~, handles)                            %#ok<DEFNU>
    global maskROI;
    global x_pos;
    global y_pos;

    global gFlags;                  % global control flags struct

    h1=impoint(handles.axes_image);
    del_roi_pos=getPosition(h1);

    numROI = length(maskROI);

    % prevent deleting the last ROI during aquisition
    if (numROI == 1) && gFlags.data_aquisition_enabled
        disp('error - can not delete the last ROI during acquisition');
        warndlg('error - can not delete the last ROI during acquisition');
    else
        for cur_ROI=numROI:-1:1 % reverse loop to delete the last ROI
            if (maskROI{cur_ROI}(round(del_roi_pos(2)),round(del_roi_pos(1)))==1) % find selected ROI
                if (cur_ROI==numROI)   % the last one
                   maskROI(numROI)=[];
                   x_pos=x_pos(:,1:numROI-1);
                   y_pos=y_pos(:,1:numROI-1);           
                else
                   %copy last one to previous location
                   maskROI{cur_ROI}=maskROI{numROI};

                   x_pos(:,cur_ROI)=x_pos(:,numROI);
                   y_pos(:,cur_ROI)=y_pos(:,numROI); 

                   maskROI(numROI)=[];
                   x_pos=x_pos(:,1:numROI-1);
                   y_pos=y_pos(:,1:numROI-1);           
                end                

                if gFlags.out_files_enabled
                    SaveROIs;                                         % save remaining ROIs to file
                    LogEvent(['ROI - Deleted #', num2str(cur_ROI)]);  % log ROI deletion
                end
                break;                                                % only delete one ROI
            end     
        end
    end

    UpdateRoiList(handles);
end

function DeleteAllRoiButton_Callback(~, ~, handles)                         %#ok<DEFNU>
    global gFlags;                 % global control flags struct

    global maskROI;
    global x_pos;
    global y_pos;

    if gFlags.data_aquisition_enabled
        disp('error - can not delete the last ROI during acquisition');
        warndlg('error - can not delete the last ROI during acquisition');
    else
        maskROI = [];
        x_pos=[];
        y_pos=[];

        if gFlags.out_files_enabled
            LogEvent('ROI - Deleted All');  % log ROI deletion
        end
    end

    UpdateRoiList(handles);
end

function Add30RoiButton_Callback(~, ~, handles)                             %#ok<DEFNU>
    global gFlags;      % global control flags struct

    for i=1:30
        h1=impoint(handles.axes_image);
        AddPointRoiButton_Callback([],[],handles,getPosition(h1));
    end

    if gFlags.out_files_enabled
        LogEvent('ROI - 30 Added');  % log ROI addition
    end

    UpdateRoiList(handles);
end

function AddAutoRoiButton_Callback(~, ~, handles)                           %#ok<DEFNU> %XXXEXPERIMENTAL
    global vid_file_root_name;      % name of video output file
    
    max_rois = 300; %XXX
    %XXX img_smooth_size = 6;            % image smoothing window size (pix)
    
    % circle segmentation parameters
    param_bg_discsize = 15;
    param_sensitivity   = 0.95;
    param_edgethreshold = 0.05;
    param_radius_range = [8,13];    % good for x20

    if isempty(vid_file_root_name)
        disp('error - bad video filename');
        warndlg('error - bad video filename');
    else
        % find available video filename
        vid_file_suffix = 0;
        vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix + 1)];
        while exist([vid_file_name,'.mat'],'file') == 2
            vid_file_suffix = vid_file_suffix + 1;
            vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix + 1)];
        end
        
        if vid_file_suffix == 0
            disp('error - video file not found');
            warndlg('error - video file not found');
        else
            vid_file_name = [vid_file_root_name,'.',num2str(vid_file_suffix),'.mat'];
            
            % get video images
            loaded_vid  = load(vid_file_name);
            frame_names = fieldnames(loaded_vid.vid_struct);
            for curr_frame_idx = 1:numel(frame_names)
                curr_frame_name = frame_names{curr_frame_idx};
                frame_img_mat(:,:,curr_frame_idx) = loaded_vid.vid_struct.(curr_frame_name).image;
            end            
            frame_img_mat = single(frame_img_mat);
%XXX             
%             % smooth video images
%             smooth_img_mat = zeros(size(frame_img_mat));
%             for i = 1:size(frame_img_mat,3)
%                 smooth_img_mat(:,:,i) = medfilt2(frame_img_mat(:,:,i),[img_smooth_size,img_smooth_size]);
%             end
%
%             img_mean = mean(smooth_img_mat,3);

            % mean video images
            img_mean = mean(frame_img_mat,3);

            % remove background illumination
            img_preseg = img_mean;
            
            img_preseg(isnan(img_preseg)) = 0;
            openedImage = (img_preseg - imopen(img_preseg,strel('disk',param_bg_discsize)));         
            openedImage = openedImage*(1/max(openedImage(:)));                              % stretch image over entire dynamic range (0-1)

            % find circles
            [centers, radii] = imfindcircles(openedImage,param_radius_range,'Sensitivity',param_sensitivity,'EdgeThreshold',param_edgethreshold);

            % add ROI for each circle found up to max #rois defined
            num_rois = min(max_rois,size(centers,1));
            for curr_center_id = 1:num_rois   
                AddPointRoiButton_Callback([],[],handles,centers(curr_center_id,:));
            end
        end
    end
end

function NextRoiBunchButton_Callback(~,~,handles)                           %#ok<DEFNU>
    global roi_bunch_size;         % number of ROIs to select when selecting a bunch
    
    selected_list = get(handles.roi_list,'Value');
    all_list      = get(handles.roi_list,'String');
    
    if ~isempty(all_list)
        all_last = length(all_list);

        if isempty(selected_list)
            new_selected_first = 1;
        else
            selected_last   = selected_list(end);

            if (selected_last + 1) > all_last
                new_selected_first = 1;
            else
                new_selected_first = selected_last + 1;
            end
        end

        if (new_selected_first + roi_bunch_size - 1) > all_last
            new_selected_last = all_last;
        else
            new_selected_last = new_selected_first + roi_bunch_size - 1;
        end

        new_selected_list = new_selected_first:new_selected_last;

        set(handles.roi_list,'Value',new_selected_list);
    end
end

%--------------------------------------------------------------------------
% Andor Camera Control Functions
%--------------------------------------------------------------------------

function InitializeAndorCamera(handles)
    global gAndor;                 % global camera struct
    
    % Camera settings - we probably don't want to modify
    AcquisitionMode     = 5;    % 5 - Run till abort
    ReadMode            = 4;    % 4 - Image
    TriggerMode         = 0;    % 0 - Internal
    ShutterInternalMode = 1;    % 1 - Open, setting to 0 (Auto) does not produce images for unknown reasons
    ShutterType         = 1;    % 1 - TTL high
    ClosingTime         = 0;    % time shutter takes to close (in ms)
    OpeningTime         = 0;    % time shutter takes to open (in ms)     
    KinCycleTime        = 0;    % minimal time delay between image (in s)
    EMGainMode          = 2;    % 2 - linear emgain mode
    HSSpeedType         = 0;    % 0 - electron multiplication
    HSSpeedIndex        = 0;    % ?XXX
    VSSpeedIndex        = 4;    % ?XXX

    % add andor libraries to the path
    addpath(fullfile(matlabroot,'toolbox','Andor'))
    addpath(fullfile(matlabroot,'toolbox','Andor','Camera Files'))

    % cd to andor libraries
    installpath = fullfile(matlabroot,'toolbox','Andor','Camera Files');
    cd (installpath);

    % init andor
    disp('AndorInitialize ---------------------------------------');
    ret.AndorInitialize = AndorInitialize(path);
    disp(['ret.AndorInitialize = ',num2str(ret.AndorInitialize)]);

    % set andor hardware acquisition parameters
    [ret.GetDetector,xpixels,ypixels] = GetDetector;                                            % get ccd pixel size
    [ret.SetImage]                    = SetImage(gAndor.xbin,gAndor.ybin,1,xpixels,1,ypixels);  % set binning
    [ret.CoolerON]                    = CoolerON;                                               % start the cooling system
    [ret.SetTemperature]              = SetTemperature(gAndor.setTemp); 
    [ret.SetAcquisitionMode]          = SetAcquisitionMode(AcquisitionMode);
    [ret.SetReadMode]                 = SetReadMode(ReadMode);
    [ret.SetShutter]                  = SetShutter(ShutterType,ShutterInternalMode,ClosingTime,OpeningTime);
    [ret.SetExposureTime]             = SetExposureTime(gAndor.ExposureTime);
    [ret.SetTriggerMode]              = SetTriggerMode(TriggerMode);
    [ret.SetKineticCycleTime]         = SetKineticCycleTime(KinCycleTime);
    [ret.SetPreAmpGain]               = SetPreAmpGain(gAndor.preAmp);
    [ret.SetEMGainMode]               = SetEMGainMode(EMGainMode);
    [ret.SetEMCCDGain]                = SetEMCCDGain(gAndor.EMGain);
    [ret.SetEMAdvanced]               = SetEMAdvanced(gAndor.EMGainAdvanced);
    [ret.SetHSSpeed]                  = SetHSSpeed(HSSpeedType,HSSpeedIndex);
    [ret.SetVSSpeed]                  = SetVSSpeed(VSSpeedIndex);

    % get actual frame duration
    [ret.GetAcquisitionTimings,~,~,gAndor.validKinTime] = GetAcquisitionTimings; 
    
    % update gui camera parameters
    set(handles.ExposureText,'String',num2str(gAndor.validKinTime));
    set(handles.EMGainText,'String',num2str(gAndor.EMGain));

    % get image buffer size
    [ret.GetSizeOfCircularBuffer,gAndor.cam_buffer_size] = GetSizeOfCircularBuffer;

    % adjust image size for binning
    gAndor.imWidth  = xpixels / gAndor.xbin;
    gAndor.imHeight = ypixels / gAndor.ybin;
end

function SetTempButton_Callback(~, ~, handles)
    global gAndor;                 % global camera struct
    
    newTemp = str2double(get(handles.SetTempText,'String'));
    [ret.SetTemperature] = SetTemperature(newTemp);
    if ret.SetTemperature == 20002
        gAndor.setTemp = newTemp;
    else
        disp('error - setting target temperature');
        warndlg('error - setting target temperature');
    end
end

function SetTempText_KeyPressFcn(~, eventdata, handles)                     %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetTempButton,'Enable','off');
        pause(0.1);
        set(handles.SetTempButton,'Enable','on');
        SetTempButton_Callback([],[], handles);
    end
end

function GetTempButton_Callback(~, ~, handles)                              %#ok<DEFNU>
    [ret.GetTemperature,measured_temp] = GetTemperature;
    set(handles.GetTempText,'String',num2str(measured_temp));
end

function SetEMGainButton_Callback(~, ~, handles)
    global gFlags;    % global control flags struct
    global gAndor;    % global camera struct

    newGain = str2double(get(handles.SetGainText,'String'));
    [ret.SetEMCCDGain] = SetEMCCDGain(newGain);

    if ret.SetEMCCDGain ~= 20002;        
        disp('error setting EMGain');
    end
    
    [ret.GetEMCCDGain,returnedGain] = GetEMCCDGain;
    gAndor.EMGain = returnedGain;
    set(handles.EMGainText,'String',num2str(gAndor.EMGain));
    
    if gFlags.out_files_enabled
        LogEvent(['EMGain - ', num2str(gAndor.EMGain)]);
    end
    
    pause(0.5);
    ContrastAdjustButton_Callback([], [], handles);
end

function SetGainText_KeyPressFcn(~, eventdata, handles)                     %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetEMGainButton,'Enable','off');
        pause(0.1);
        set(handles.SetEMGainButton,'Enable','on');
        SetEMGainButton_Callback([],[], handles);
    end
end

function SetEMGain0Button_Callback(~, ~, handles)                           %#ok<DEFNU>
    set(handles.SetGainText,'String','0');
    SetEMGainButton_Callback([],[], handles);
end

function SetEMGain300Button_Callback(~, ~, handles)                         %#ok<DEFNU>
    set(handles.SetGainText,'String','300');
    SetEMGainButton_Callback([],[], handles);
end

function SetExposureButton_Callback(~, ~, handles)
    global gFlags;    % global control flags struct
    global gAndor;    % global camera struct
    
    if gFlags.preview_enabled
        disp('error - can not change exposure during preview');
        warndlg('error - can not change exposure during preview');
    else
        newExposure = str2double(get(handles.SetExposureText,'String'));
        [ret.SetExposureTime] = SetExposureTime(newExposure);

        if ret.SetExposureTime ~= 20002;        
            disp('error - setting exposure');
        end

        [ret.GetAcquisitionTimings,~,~,gAndor.validKinTime] = GetAcquisitionTimings; 
        set(handles.ExposureText,'String',num2str(gAndor.validKinTime));

        if gFlags.out_files_enabled
            LogEvent(['Exposure - ', num2str(gAndor.validKinTime)]);
        end    
    end
end

function SetExposureText_KeyPressFcn(~, eventdata, handles)                 %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetExposureButton,'Enable','off');
        pause(0.1);
        set(handles.SetExposureButton,'Enable','on');
        SetExposureButton_Callback([],[], handles);
    end
end

%--------------------------------------------------------------------------
% BK 4079 Function Generator Control Functions
%--------------------------------------------------------------------------

function InitFunctionGeneratorButton_Callback(~, ~, handles)                %#ok<DEFNU>
    global gFunctionGenerator;      % global function generator struct
    
    fg_identity = 'B&K,MODEL4079,0,V1.45';

    gFunctionGenerator.handle = instrfind('Type', 'gpib', 'BoardIndex', 0, 'PrimaryAddress', 9, 'Tag', '');
    if isempty(gFunctionGenerator.handle)
        gFunctionGenerator.handle = gpib('NI', 0, 9);
    else
        fclose(gFunctionGenerator.handle);
        gFunctionGenerator.handle = gFunctionGenerator.handle(1);
    end
    fopen(gFunctionGenerator.handle)                                        %#ok<PRTCAL>
    
    % get function generator identity string
    fprintf(gFunctionGenerator.handle, '*IDN?');               
    fg_identity_reply = fscanf(gFunctionGenerator.handle,'%s');
    
    if ~strcmp(fg_identity,fg_identity_reply)
        disp('error - can not connect to B&K function generator');
        warndlg('error - can not connect to B&K function generator');
    else
        fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off ch1 output, this prevents surges
        fprintf(gFunctionGenerator.handle,':OUTP2:STAT OFF');    % turn off ch2 output, this prevents surges
    
        fprintf(gFunctionGenerator.handle, '*RST');              % reset function generator
        
        fprintf(gFunctionGenerator.handle,[':SOURce:FREQuency ',num2str(gFunctionGenerator.Frequency),'KHz']);   % set frequency (KHz) (0.001mHz - 10MHz)
        fprintf(gFunctionGenerator.handle,[':SOURce:VOLTage:AMPLitude ',num2str(gFunctionGenerator.Amplitude)]); % set amplitude (V p-p) (0.01V-10V)
        fprintf(gFunctionGenerator.handle,[':SOURce:FUNC ',gFunctionGenerator.Function]);                        % set function shape
        fprintf(gFunctionGenerator.handle,[':TRIGger:MODE ',gFunctionGenerator.TriggerMode]);                    % set trigger mode
        fprintf(gFunctionGenerator.handle,[':TRIGger:BURSt ',num2str(gFunctionGenerator.BurstCount)]);           % set burst count (2-999999)
        fprintf(gFunctionGenerator.handle,[':TRIGger:SOURce ',gFunctionGenerator.TriggerSource]);                % set trigger source
        
        fprintf(gFunctionGenerator.handle,[':SOUR2:FREQ ',num2str(gFunctionGenerator.Ch2_Frequency),'KHz']);     % set ch2 frequency (KHz) (0.001mHz - 10MHz)
        fprintf(gFunctionGenerator.handle,[':SOUR2:VOLT:AMPL ',num2str(gFunctionGenerator.Ch2_Amplitude)]);      % set ch2 amplitude (V p-p) (0.01V-10V)
        fprintf(gFunctionGenerator.handle,[':SOUR2:FUNC ',gFunctionGenerator.Ch2_Function]);                     % set ch2 function shape
        fprintf(gFunctionGenerator.handle,[':TRIG2:MODE ',gFunctionGenerator.Ch2_TriggerMode]);                  % set ch2 trigger mode
        fprintf(gFunctionGenerator.handle,[':TRIG2:BURS ',num2str(gFunctionGenerator.Ch2_BurstCount)]);          % set ch2 burst count (2-999999)
        fprintf(gFunctionGenerator.handle,[':TRIG2:SOUR ',gFunctionGenerator.Ch2_TriggerSource]);                % set ch2 trigger source
                
        GetFunctionGeneratorParameters(handles);
    end
    
    % turn on ch2 output
    fprintf(gFunctionGenerator.handle,':OUTP2:STAT ON');    % turn ch2 output back on, was turned off to prevent surges
end

% get the function generator parameters
function GetFunctionGeneratorParameters(handles)
    global gFlags;                  % global control flags struct
    global gFunctionGenerator;      % global function generator struct
    
    fprintf(gFunctionGenerator.handle, ':SOURce:FREQuency?');
    fg_frequency_Hz = fscanf(gFunctionGenerator.handle,'%s');               % in Hz
    fg_frequency_KHz = num2str(str2double(fg_frequency_Hz) / 1000);
    set(handles.FrequencyText,'String',fg_frequency_KHz);

    fprintf(gFunctionGenerator.handle, ':SOURce:VOLTage:AMPLitude?');
    fg_amplitude = fscanf(gFunctionGenerator.handle,'%s');                  % in Volt p-p
    set(handles.AmplitudeText,'String', num2str(str2double(fg_amplitude)));

    fprintf(gFunctionGenerator.handle, ':SOURce:FUNC?');
    fg_function = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.FunctionText,'String',fg_function);

    fprintf(gFunctionGenerator.handle, ':TRIGger:MODE?');
    fg_trigger_mode = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.TriggerModeText,'String',fg_trigger_mode);
    
    fprintf(gFunctionGenerator.handle, ':TRIGger:SOURce?');
    fg_trigger_source = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.TriggerSourceText,'String',fg_trigger_source);

    fprintf(gFunctionGenerator.handle, ':TRIGger:BURSt?');
    fg_burst_count = fscanf(gFunctionGenerator.handle,'%s');   
    if strcmp(fg_trigger_mode,'BURS')
        set(handles.CycleCountText,'String',fg_burst_count);
    elseif strcmp(fg_trigger_mode,'TRIG')
        set(handles.CycleCountText,'String','1');
    end
    
    fprintf(gFunctionGenerator.handle, ':SOUR2:FREQ?');
    fg_ch2_frequency_Hz = fscanf(gFunctionGenerator.handle,'%s');               % in Hz
    fg_ch2_frequency_KHz = num2str(str2double(fg_ch2_frequency_Hz) / 1000);
    set(handles.Ch2FrequencyText,'String',fg_ch2_frequency_KHz);
    
    fprintf(gFunctionGenerator.handle, ':SOUR2:VOLT:AMPL?');
    fg_ch2_amplitude = fscanf(gFunctionGenerator.handle,'%s');                  % in Volt p-p
    set(handles.Ch2AmplitudeText,'String', num2str(str2double(fg_ch2_amplitude)));
 
    fprintf(gFunctionGenerator.handle, ':SOUR2:FUNC?');
    fg_ch2_function = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.Ch2FunctionText,'String',fg_ch2_function);

    fprintf(gFunctionGenerator.handle, ':TRIG2:MODE?');
    fg_ch2_trigger_mode = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.Ch2TriggerModeText,'String',fg_ch2_trigger_mode);
    
    fprintf(gFunctionGenerator.handle, ':TRIG2:SOUR?');
    fg_ch2_trigger_source = fscanf(gFunctionGenerator.handle,'%s');
    set(handles.Ch2TriggerSourceText,'String',fg_ch2_trigger_source);

    fprintf(gFunctionGenerator.handle, ':TRIG2:BURS?');
    fg_ch2_burst_count = fscanf(gFunctionGenerator.handle,'%s');
    if strcmp(fg_ch2_trigger_mode,'BURS')
        set(handles.Ch2BurstCountText,'String',fg_ch2_burst_count);    
    elseif strcmp(fg_ch2_trigger_mode,'TRIG')
        set(handles.Ch2BurstCountText,'String','1');    
    end

    
    
    if gFlags.out_files_enabled
        log_string = [                                       ...
            'Function Generator Parameters - ',              ...
            fg_frequency_KHz,'KHz ',                         ...
            num2str(str2double(fg_amplitude)),'V ',          ...
            fg_function,' ',                                 ...
            fg_trigger_mode,' ',                             ...
            fg_trigger_source,                               ...
            ' #',num2str(fg_burst_count),                    ...
            ];

        log_string_ch2 = [ ...
            'Channel 2 Parameters - ',                       ...
            fg_ch2_frequency_KHz,'KHz ',                     ...
            num2str(str2double(fg_ch2_amplitude)),'V ',      ...
            fg_ch2_function,' ',                             ...
            fg_ch2_trigger_mode,' ',                         ...
            fg_ch2_trigger_source,                           ...
            ' #',num2str(fg_ch2_burst_count),                ...
            ];
        
        LogEvent(log_string);
        LogEvent(log_string_ch2);
    end
end

function TriggerButton_Callback(~, ~, handles)
    global gFlags;                 % global control flags struct
    global gTrigger;               % global trigger struct
    
    if ~gTrigger.save_trigger_video_flag && ~gTrigger.control_shutter_flag
        TriggerFunctionGenerator([],[],handles);         % trigger the function generator
    elseif gTrigger.save_trigger_video_flag && ~gTrigger.control_shutter_flag                  % only save video enabled
        % start saving video
        TriggerPreVideoTimerHandler([],[],handles);
        
        % trigger the function generator after a delay
        delete(gTrigger.video_pre_timer);
        gTrigger.video_pre_timer = timer('Name',          'TriggerVideoPreTimer',     ...
                                         'ExecutionMode', 'singleShot',               ...
                                         'StartDelay',    gTrigger.video_pre_trigger, ...
                                         'TimerFcn',      {@TriggerFunctionGenerator, handles});
        start(gTrigger.video_pre_timer);
                                     
        % stop saving the video after an additional delay
        delete(gTrigger.video_post_timer);                             
        gTrigger.video_post_timer = timer('Name',          'TriggerVideoPostTimer',                                 ...
                                          'ExecutionMode', 'singleShot',                                            ...
                                          'StartDelay', (gTrigger.video_pre_trigger + gTrigger.video_post_trigger), ...
                                          'TimerFcn', {@TriggerPostVideoTimerHandler, handles});
        start(gTrigger.video_post_timer);
    elseif ~gTrigger.save_trigger_video_flag && gTrigger.control_shutter_flag                  % only shutter control enabled
        % open the shutter
        ShutterOnButton_Callback([],[],handles);
        
        % trigger the function generator after a delay
        delete(gTrigger.shutter_pre_timer);
        gTrigger.shutter_pre_timer = timer('Name',          'TriggerShutterPreTimer',     ...
                                           'ExecutionMode', 'singleShot',                 ...
                                           'StartDelay',    gTrigger.shutter_pre_trigger, ...
                                           'TimerFcn',      {@TriggerFunctionGenerator, handles});
        start(gTrigger.shutter_pre_timer);
                                     
        % close the shutter after an additional delay
        delete(gTrigger.shutter_post_timer);                             
        gTrigger.shutter_post_timer = timer('Name',          'TriggerShutterPostTimer',                                   ...
                                            'ExecutionMode', 'singleShot',                                                ...
                                            'StartDelay', (gTrigger.shutter_pre_trigger + gTrigger.shutter_post_trigger), ...
                                            'TimerFcn', {@ShutterOffButton_Callback, handles});
        start(gTrigger.shutter_post_timer);
    elseif gTrigger.save_trigger_video_flag && gTrigger.control_shutter_flag                   % both save video and shutter control enabled
        shutter_pre_video = gTrigger.shutter_pre_trigger - gTrigger.video_pre_trigger;
        if shutter_pre_video <= 0
            disp('error - shutter trigger delay not bigger than video trigger delay');
            warndlg('error - shutter trigger delay not bigger than video trigger delay');
        else
            % open the shutter
            ShutterOnButton_Callback([],[],handles);
            
            % start saving the video after a delay
            delete(gTrigger.video_pre_timer);                             
            gTrigger.video_pre_timer = timer('Name',           'TriggerVideoPreTimer',                     ...
                                              'ExecutionMode', 'singleShot',                               ...
                                              'StartDelay',    shutter_pre_video,                          ...
                                              'TimerFcn',      {@TriggerPreVideoTimerHandler, handles});
            start(gTrigger.video_pre_timer);
            
            % trigger the function generator after an aditional delay
            delete(gTrigger.shutter_pre_timer);
            gTrigger.shutter_pre_timer = timer('Name',          'TriggerShutterPreTimer',     ...
                                               'ExecutionMode', 'singleShot',                 ...
                                               'StartDelay',    gTrigger.shutter_pre_trigger, ...
                                               'TimerFcn',      {@TriggerFunctionGenerator, handles});
            start(gTrigger.shutter_pre_timer);
            
            
            % stop saving the video after an additional delay
            delete(gTrigger.video_post_timer);                             
            gTrigger.video_post_timer = timer('Name',          'TriggerVideoPostTimer',                                        ...
                                              'ExecutionMode', 'singleShot',                                                   ...
                                              'StartDelay',    (gTrigger.shutter_pre_trigger + gTrigger.video_post_trigger),   ...
                                              'TimerFcn',      {@TriggerPostVideoTimerHandler, handles});
            start(gTrigger.video_post_timer);

            % close the shutter after an additional delay
            delete(gTrigger.shutter_post_timer);                             
            gTrigger.shutter_post_timer = timer('Name',          'TriggerShutterPostTimer',                                      ...
                                                'ExecutionMode', 'singleShot',                                                   ...
                                                'StartDelay',    (gTrigger.shutter_pre_trigger + gTrigger.shutter_post_trigger), ...
                                                'TimerFcn',      {@ShutterOffButton_Callback, handles});
            start(gTrigger.shutter_post_timer);
        end
    end
end

% activated by pre-trigger video timer
function TriggerPreVideoTimerHandler(~,~,handles)
        set(handles.KeepVideoCheckbox,'Value',true);
        KeepVideoCheckbox_Callback([],[],handles);
end

% activated by post-trigger video timer
function TriggerPostVideoTimerHandler(~,~,handles)
        set(handles.KeepVideoCheckbox,'Value',false);
        KeepVideoCheckbox_Callback([],[],handles);
        
        SaveVidBufferButton_Callback([],[],handles);
end

% trigger the function generator
function TriggerFunctionGenerator(~,~,handles)
    global gFunctionGenerator;      % global function generator struct    
    global gFlags;                  % global control flags struct
    global gTrigger;                % global trigger struct
    global gScope;                  % global oscilloscope struct

    global root_file_name;          % root name for output files
    
    % check that the function generator has been initialized
    if isempty(gFunctionGenerator.handle)
        disp('error - trigger attempted without an initialized function generator');
        warndlg('error - trigger attempted without an initialized function generator');
    else
        % disable the trigger button
        set(handles.TriggerButton,'Enable','off');
                
        % prepare scope for measurement (if scope use is enabled)
        if gTrigger.use_scope_flag
            SetScopeVerticalScale();                        % set scope vertical scale
            RunScopeCommand('*WAI',false);                  % complete all previous scope operations before running any folowing commands
            RunScopeCommand('ACQuire:STATE ON',false);      % start aquisition
            WaitOnScopeAquisitionState(true);               % wait for aquisition to start
        end
        
        % trigger
        pre_trigger_time = toc;             % get time before trigger
        trigger(gFunctionGenerator.handle); % send a trigger to the function generator
        post_trigger_time = toc;            % get time after trigger
        gTrigger.triggered_flag = 1;        % flag that a trigger has been pulled 
        gong(1000,3000,0.3);                % sound a beep

        trigger_last_time = mean([pre_trigger_time,post_trigger_time]); % estimate trigger time
        gTrigger.trigger_times(end+1) = trigger_last_time;

        if gFlags.out_files_enabled
            trigger_file_name = [root_file_name, '.triggers'];              % append tag to data file name
            trigger_file_handle = fopen(trigger_file_name,'at')             %#ok<NOPRT>
            fprintf(trigger_file_handle,'%f\n',trigger_last_time);
            fclose(trigger_file_handle);
        end
         
        % measure triggered output using scope (if scope use is enabled)
        if gTrigger.use_scope_flag && ~isempty(gScope.handle)
            GetScopeMeasurmentsAsync(handles);
        else
            % enable trigger button
            set(handles.TriggerButton,'Enable','on');
        end
    
        HandleProgVolt(handles);                                            % adjust voltage if program voltage is enabled
    end
end

function TriggerLoopBox_Callback(~,~,handles)
    global gFlags;                          % global control flags struct
    global gTrigger;                        % global trigger struct

    % update trigger period in the checkbox text
    set(handles.TriggerLoopBox, 'String', ['Trigger Every ',num2str(gTrigger.trigger_loop_delay),' sec']);

    if get(handles.TriggerLoopBox,'Value')     % if the checkbox is checked
        % enable trigger loop
        gTrigger.trigger_loop_flag = true;
        gTrigger.trigger_loop_timer = timer('Name',          'TriggerLoopTimer',          ...
                                            'ExecutionMode', 'fixedRate',                 ...
                                            'period',        gTrigger.trigger_loop_delay, ...
                                            'TimerFcn',      {@TriggerLoopTimerHandler, handles});
        start(gTrigger.trigger_loop_timer);

        set(handles.NextTriggerTxt,'String',['Next Trigger - ',datestr(now+datenum(0,0,0,0,0,gTrigger.trigger_loop_delay),'HH:MM:ss')]);

        if gFlags.out_files_enabled
            LogEvent(['Trigger Loop Enabled - ',num2str(gTrigger.trigger_loop_delay),' sec']);
        end
    else                        % if the checkbox is unchecked
        % disable trigger loop
        gTrigger.trigger_loop_flag = false;
        stop(gTrigger.trigger_loop_timer);
        delete(gTrigger.trigger_loop_timer);

        set(handles.NextTriggerTxt,'String','Next Trigger - ');

        if gFlags.out_files_enabled
            LogEvent('Trigger Loop Disabled');
        end
    end
end

% activated by trigger-loop timer
function TriggerLoopTimerHandler(~,~,handles)
    global gTrigger;                % global trigger struct
    
    set(handles.NextTriggerTxt,'String',['Next Trigger - ',datestr(now+datenum(0,0,0,0,0,gTrigger.trigger_loop_delay),'HH:MM:ss')]);
    TriggerButton_Callback([],[],handles);
end

function SetIntervalButton_Callback(~, ~, handles)
    global gTrigger;               % global trigger struct

    % set new period between triggers
    gTrigger.trigger_loop_delay = str2double(get(handles.SetIntervalText,'String'));

    % update the checkbox text with the new period only of a trigger loop is not currently enabled
    if get(handles.TriggerLoopBox,'Value') == 0
        set(handles.TriggerLoopBox,'String',['Trigger Every ',num2str(gTrigger.trigger_loop_delay),' sec']);
    end
end

function SetIntervalText_KeyPressFcn(~, eventdata, handles)                 %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetIntervalButton,'Enable','off');
        pause(0.1);
        set(handles.SetIntervalButton,'Enable','on');
        SetIntervalButton_Callback([],[], handles);
    end
end

function SetCycleCountButton_Callback(~, ~, handles)
    global gFunctionGenerator;      % global function generator struct
    
    gFunctionGenerator.BurstCount = str2double(get(handles.SetCycleCountText,'String'));
    
    if (gFunctionGenerator.BurstCount < 2 || gFunctionGenerator.BurstCount > 999999)
        disp('error - burst # must be between 2 and 999999');
        warndlg('error - burst # must be between 2 and 999999');
    else
        % check if output is on before changing, if it is then turn it off (and on again later after the change) this prevents surges
        fprintf(gFunctionGenerator.handle, ':OUTPut:STATe?');
        output_state = fscanf(gFunctionGenerator.handle,'%s');
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off output
        end

        fprintf(gFunctionGenerator.handle,[':TRIGger:BURSt ',num2str(gFunctionGenerator.BurstCount)]);  % set burst count
        GetFunctionGeneratorParameters(handles);
        
        % if output was on then turn it back on
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe ON');  % turn on output
        end       
    end
end

function SetCycleCountText_KeyPressFcn(~, eventdata, handles)               %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetCycleCountButton,'Enable','off');
        pause(0.1);
        set(handles.SetCycleCountButton,'Enable','on');
        SetCycleCountButton_Callback([],[], handles);
    end
end

function SetAmplitudeButton_Callback(~, ~, handles)
    global gFunctionGenerator;      % global function generator struct
    
     if isempty(gFunctionGenerator.handle)
        disp('error - amplitude change attempted without an initialized function generator');
        warndlg('error - amplitude change attempted without an initialized function generator');
     else    
        gFunctionGenerator.Amplitude = str2double(get(handles.SetAmplitudeText,'String'));

        if (gFunctionGenerator.Amplitude < 0.01 || gFunctionGenerator.Amplitude > 10)
            disp('error - amplitude must be between 0.01V and 10V');
            warndlg('error - amplitude must be between 0.01V and 10V');
        else
            % check if output is on before changing voltage, if it is then turn it off (and on again later after the voltage change) this prevents surges
            fprintf(gFunctionGenerator.handle, ':OUTPut:STATe?');
            output_state = fscanf(gFunctionGenerator.handle,'%s');
            if strcmp(output_state,'1')
                fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off output
            end
            
            % change voltage
            fprintf(gFunctionGenerator.handle,[':SOURce:VOLTage:AMPLitude ',num2str(gFunctionGenerator.Amplitude)]);  % set amplitude
            GetFunctionGeneratorParameters(handles);
            
            % if output was on then turn it back on
            if strcmp(output_state,'1')
                fprintf(gFunctionGenerator.handle,':OUTPut:STATe ON');  % turn on output
            end
        end
     end
end

function SetAmplitudeText_KeyPressFcn(~, eventdata, handles)                %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetAmplitudeButton,'Enable','off');
        pause(0.1);
        set(handles.SetAmplitudeButton,'Enable','on');
        SetAmplitudeButton_Callback([],[], handles);
    end
end

function SetFrequencyButton_Callback(~, ~, handles)
    global gFunctionGenerator;      % global function generator struct
    
    gFunctionGenerator.Frequency = str2double(get(handles.SetFrequencyText,'String'));  % in KHz
    
    if (gFunctionGenerator.Frequency < 1e-9 || gFunctionGenerator.Frequency > 10000)
        disp('error - frequency must be between 0.001mHz and 10MHz');
        warndlg('error - frequency must be between 0.001mHz and 10MHz');
    else
        % check if output is on before changing, if it is then turn it off (and on again later after the change) this prevents surges
        fprintf(gFunctionGenerator.handle, ':OUTPut:STATe?');
        output_state = fscanf(gFunctionGenerator.handle,'%s');
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off output
        end
        
        fprintf(gFunctionGenerator.handle,[':SOURce:FREQuency ',num2str(gFunctionGenerator.Frequency),'KHz']);    % set frequency
        GetFunctionGeneratorParameters(handles);
        
        % if output was on then turn it back on
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe ON');  % turn on output
        end
    end
end

function SetFrequencyText_KeyPressFcn(~, eventdata, handles)                %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetFrequencyButton,'Enable','off');
        pause(0.1);
        set(handles.SetFrequencyButton,'Enable','on');
        SetFrequencyButton_Callback([],[], handles);
    end
end

function SetPulseCountButton_Callback(~, ~, handles)
    global gFunctionGenerator;      % global function generator struct

    % check if output is on before changing, if it is then turn it off (and on again later after the change) this prevents surges
    fprintf(gFunctionGenerator.handle, ':OUTPut:STATe?');
    output_state = fscanf(gFunctionGenerator.handle,'%s');
    if strcmp(output_state,'1')
        fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off output
    end
    
    % get wanted pulse count
    New_Pulse_Count = str2double(get(handles.SetPulseCountText,'String'));
     
    % change pulse count
    if New_Pulse_Count == 1
        gFunctionGenerator.Ch2_TriggerMode = 'TRIG';                                                % set trigger mode - for a single pulse this should be TRIG, for multiple pulses BURS
        fprintf(gFunctionGenerator.handle,[':TRIG2:MODE ',gFunctionGenerator.Ch2_TriggerMode]);
    elseif (New_Pulse_Count > 1) && (New_Pulse_Count <= 999999)
        gFunctionGenerator.Ch2_TriggerMode = 'BURS';                                                % set trigger mode - for a single pulse this should be TRIG, for multiple pulses BURS
        fprintf(gFunctionGenerator.handle,[':TRIG2:MODE ',gFunctionGenerator.Ch2_TriggerMode]);
        
        gFunctionGenerator.Ch2_BurstCount  = New_Pulse_Count;
        fprintf(gFunctionGenerator.handle,[':TRIG2:BURSt ',num2str(gFunctionGenerator.Ch2_BurstCount)]);  % set burst count
    else
        disp('error - pulse # must be between 1 and 999999');
        warndlg('error - pulse # must be between 1 and 999999');
    end

    % if output was on then turn it back on
    if strcmp(output_state,'1')
        fprintf(gFunctionGenerator.handle,':OUTPut:STATe ON');  % turn on output
    end   

    GetFunctionGeneratorParameters(handles);
end

function SetPulseCountText_KeyPressFcn(~, eventdata, handles)               %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetPulseCountButton,'Enable','off');
        pause(0.1);
        set(handles.SetPulseCountButton,'Enable','on');
        SetPulseCountButton_Callback([],[], handles);
    end
end

function SetPulseFrequencyButton_Callback(~, ~, handles)
    global gFunctionGenerator;      % global function generator struct
    
    gFunctionGenerator.Ch2_Frequency = str2double(get(handles.SetPulseFrequencyText,'String'));  % in KHz
    
    if (gFunctionGenerator.Ch2_Frequency < 1e-9 || gFunctionGenerator.Ch2_Frequency > 10000)
        disp('error - pulse frequency must be between 0.001mHz and 10MHz');
        warndlg('error - pulse frequency must be between 0.001mHz and 10MHz');
    else
        % check if output is on before changing, if it is then turn it off (and on again later after the change) this prevents surges
        fprintf(gFunctionGenerator.handle, ':OUTPut:STATe?');
        output_state = fscanf(gFunctionGenerator.handle,'%s');
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe OFF');  % turn off output
        end
        
        fprintf(gFunctionGenerator.handle,[':SOUR2:FREQ ',num2str(gFunctionGenerator.Ch2_Frequency),'KHz']);    % set frequency
        GetFunctionGeneratorParameters(handles);
        
        % if output was on then turn it back on
        if strcmp(output_state,'1')
            fprintf(gFunctionGenerator.handle,':OUTPut:STATe ON');  % turn on output
        end
    end
end

function SetPulseFrequencyText_KeyPressFcn(~, eventdata, handles)           %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.SetPulseFrequencyButton,'Enable','off');
        pause(0.1);
        set(handles.SetPulseFrequencyButton,'Enable','on');
        SetPulseFrequencyButton_Callback([],[], handles);
    end
end

function SaveTriggerVideoBox_Callback(~, ~, handles)
    global gFlags;                  % global control flags struct
    global gTrigger;                % global trigger struct
    
    BoxValue = get(handles.SaveTriggerVideoBox,'Value');
    
    if BoxValue == true             % if the checkbox is checked
        if ~gFlags.out_files_enabled
            disp('error - output files are not enabled');
            warndlg('error - output files are not enabled');
            
            set(handles.SaveTriggerVideoBox,'Value',false);
            gTrigger.save_trigger_video_flag = false;
        else
            gTrigger.save_trigger_video_flag = true;            
            LogEvent('Save Trigger Video Enabled');
        end        
    else                            % if the checkbox is unchecked
        gTrigger.save_trigger_video_flag = false;
        if gFlags.out_files_enabled
            LogEvent('Save Trigger Video Disabled');
        end
    end
    
end

function ProgVoltBox_Callback(~,~,handles)
    global gTrigger;               % global trigger struct
    global gFlags;                 % global control flags struct
    
    if get(handles.ProgVoltBox,'Value')             % if the checkbox is checked
        
        gTrigger.prog_volt_step        = str2double(get(handles.ProgVoltStepText, 'String'));
        gTrigger.prog_volt_final       = str2double(get(handles.ProgVoltFinalText,'String'));
        gTrigger.prog_volt_target_reps = str2double(get(handles.ProgVoltRepsText, 'String'));
        
        if isempty(gTrigger.prog_volt_step)        || isnan(gTrigger.prog_volt_step)        ...
        || isempty(gTrigger.prog_volt_final)       || isnan(gTrigger.prog_volt_final)       ...
        || isempty(gTrigger.prog_volt_target_reps) || isnan(gTrigger.prog_volt_target_reps) ...
        || gTrigger.prog_volt_step == 0            ...
        || gTrigger.prog_volt_target_reps <= 0
            disp('error - illegal program voltage parameters');
            warndlg('error - illegal program voltage parameters');
            
            set(handles.ProgVoltBox,'Value',false);
        else
            gTrigger.prog_volt_flag = true;
            gTrigger.prog_volt_curr_reps = 0;
            
            if gFlags.out_files_enabled
                LogEvent('Trigger - Program Voltage Enabled');
            end

            set(handles.ProgVoltStepText, 'Enable','off');     % disable editing of the text field
            set(handles.ProgVoltFinalText,'Enable','off');     % disable editing of the text field
            set(handles.ProgVoltRepsText, 'Enable','off');     % disable editing of the text field
            
            set(handles.RandVoltBox, 'Enable','on');           % enable the random voltage checkbox
        end
    else                                            % if the checkbox is unchecked
        gTrigger.prog_volt_flag = false;
        
        if gFlags.out_files_enabled
            LogEvent('Trigger - Program Voltage Disabled');
        end
        
        set(handles.ProgVoltStepText, 'Enable','on');           % enable editing of the text field
        set(handles.ProgVoltFinalText,'Enable','on');           % enable editing of the text field
        set(handles.ProgVoltRepsText, 'Enable','on');           % enable editing of the text field
        
        set(handles.RandVoltBox, 'Value',0);
        set(handles.RandVoltBox, 'Enable','off');               % disable the random voltage checkbox
    end
end

function HandleProgVolt(handles)
    global gTrigger;                % global trigger struct
    global gFunctionGenerator;      % global function generator struct
    global matlab_precision_bug;    % problem with matlab comparisons (0.1 + 1.1 ~= 1.2)
    
    if gTrigger.prog_volt_flag
        % randomized voltage
        if get(handles.RandVoltBox,'Value')
            if size(gTrigger.prog_volt_sequence,2) == 0
                % disable trigger loop
                if get(handles.TriggerLoopBox,'Value')
                    set(handles.TriggerLoopBox,'Value',false);
                    TriggerLoopBox_Callback([],[],handles);
                end

                % disable random voltage
                set(handles.RandVoltBox,'Value',false);
                RandVoltBox_Callback([],[],handles);
                
                % disable program voltage
                set(handles.ProgVoltBox,'Value',false);
                ProgVoltBox_Callback([],[],handles);
            else
                new_volt = gTrigger.prog_volt_sequence(end);
                set(handles.RandVoltText,'String',num2str(size(gTrigger.prog_volt_sequence,2)));
                gTrigger.prog_volt_sequence(end) = [];

                % adjust voltage
                set(handles.SetAmplitudeText,'String',num2str(new_volt));
                SetAmplitudeButton_Callback([],[],handles);
            end
        % progressive voltage
        else
            gTrigger.prog_volt_curr_reps = gTrigger.prog_volt_curr_reps + 1;
            if gTrigger.prog_volt_curr_reps >= gTrigger.prog_volt_target_reps
                new_volt = gFunctionGenerator.Amplitude + gTrigger.prog_volt_step;

                if (gTrigger.prog_volt_step > 0 && new_volt > (gTrigger.prog_volt_final + matlab_precision_bug)) ...  % trigger sequence concluded
                || (gTrigger.prog_volt_step < 0 && new_volt < gTrigger.prog_volt_final)
                    % disable trigger loop
                    if get(handles.TriggerLoopBox,'Value')
                        set(handles.TriggerLoopBox,'Value',false);
                        TriggerLoopBox_Callback([],[],handles);
                    end

                    % disable program voltage
                    set(handles.ProgVoltBox,'Value',false);
                    ProgVoltBox_Callback([],[],handles);
                else
                    % increase voltage
                    set(handles.SetAmplitudeText,'String',num2str(new_volt));
                    SetAmplitudeButton_Callback([],[],handles);
                end

                gTrigger.prog_volt_curr_reps = 0;
            end 
        end
    end
end

function RandVoltBox_Callback(~, ~, handles)
    global gTrigger;                % global trigger struct
    global gFunctionGenerator;      % global function generator struct
    global gFlags;                 % global control flags struct
    
    if get(handles.RandVoltBox,'Value')
        sequence = [gFunctionGenerator.Amplitude:gTrigger.prog_volt_step:gTrigger.prog_volt_final];
        rep_sequence = [];
        for i = 1:gTrigger.prog_volt_target_reps
            rep_sequence = [rep_sequence,sequence];
        end
        
        rng('shuffle');
        gTrigger.prog_volt_sequence = rep_sequence(randperm(length(rep_sequence)));
        
        if size(gTrigger.prog_volt_sequence,2) <= 0
            disp('error - illegal random voltage parameters');
            warndlg('error - illegal random voltage parameters');
            
            set(handles.RandVoltBox,'Value',0);
        else
            set(handles.RandVoltText,'String',num2str(size(gTrigger.prog_volt_sequence,2)));
            
            if gFlags.out_files_enabled
                LogEvent(['Trigger - Random Voltage Enabled - ',num2str(gTrigger.prog_volt_sequence)]);
            end

            % adjust voltage
            new_volt = gTrigger.prog_volt_sequence(end);
            gTrigger.prog_volt_sequence(end) = [];

            set(handles.SetAmplitudeText,'String',num2str(new_volt));
            SetAmplitudeButton_Callback([],[],handles);
        end
    else
        gTrigger.prog_volt_sequence = [];
        set(handles.RandVoltText,'String','');
        
        if gFlags.out_files_enabled
            LogEvent('Trigger - Random Voltage Disabled');
        end
    end
end

%--------------------------------------------------------------------------
% Shutter Control Functions
%--------------------------------------------------------------------------

function InitShutterPort()
   global gShutter;               % global shutter serial connection handle

    gShutter.handle = instrfind('Type', 'serial','Port','COM3','BaudRate',9600,'Tag','');
    if isempty(gShutter.handle)
        gShutter.handle = serial('COM3','BaudRate',9600);
    else
        fclose(gShutter.handle);
        gShutter.handle = gShutter.handle(1);
    end
    
    gShutter.handle.DataTerminalReady = 'off';  % make sure shutter starts closed
    fopen(gShutter.handle);
 end

function ShutterOnButton_Callback(~, ~, handles)                            %#ok<INUSD>
    global gShutter;               % global shutter serial connection handle
    global gFlags;                 % global control flags struct
    
    gShutter.handle.DataTerminalReady = 'on'; % open shutter

    if gFlags.out_files_enabled
        LogEvent('Shutter - Turned On');
    end
end

function ShutterOffButton_Callback(~, ~, handles)                           %#ok<INUSD>
    global gShutter;               % global shutter serial connection handle
    global gFlags;                 % global control flags struct
    
    gShutter.handle.DataTerminalReady = 'off'; % close shutter

    if gFlags.out_files_enabled
        LogEvent('Shutter - Turned Off');
    end
end

function ControlShutterBox_Callback(~, ~, handles)                          %#ok<DEFNU>
    global gTrigger;               % global trigger struct
    global gFlags;                 % global control flags struct
    
    if get(handles.ControlShutterBox,'Value')               % if the checkbox is checked
        gTrigger.control_shutter_flag = true;

        if gFlags.out_files_enabled
            LogEvent('Trigger - Shutter Control Enabled');
        end
    else                                                    % if the checkbox is unchecked
        gTrigger.control_shutter_flag = false;

        if gFlags.out_files_enabled
            LogEvent('Trigger - Shutter Control Disabled');
        end
    end
end

%--------------------------------------------------------------------------
% Logging Functions
%--------------------------------------------------------------------------

function EnableOutputFilesBox_Callback(~, ~, handles)
    global root_file_name;          % root name for output files
    global log_file_handle;         % handle to log file

    global gFlags;                  % global control flags struct

    entered_name = get(handles.RootFileNameText,'String');
    toggle_state = get(handles.EnableOutputFilesBox,'Value');
    if toggle_state                                           % if user enabled the checkbox
        if exist(entered_name,'file')               == 2 || ... % if some output files with this root already exist
           exist([entered_name,'.triggers'],'file') == 2 || ...
           exist([entered_name,'.rois.mat'],'file') == 2 || ...
           exist([entered_name,'.data'],'file')     == 2 || ...
           exist([entered_name,'.vid.mat'],'file')  == 2 || ...
           exist([entered_name,'.log'],'file')      == 2   

            set(handles.EnableOutputFilesBox,'Value',0);           % keep the checkbox disabled
            gFlags.out_files_enabled = false;                      % disable output to files
            disp('error - some output files already exist');
            warndlg('error - some output files already exist');
        else                                                    % if no files exist
            root_file_name = entered_name;
            gFlags.out_files_enabled = true;                       % enable output to files
            set(handles.RootFileNameText,'Enable','inactive');     % disable editing of the text field

            log_file_handle = fopen([root_file_name,'.log'], 'at') %#ok<NOPRT> % open the log file
            StartEventLog;
        end    
    else                                                      % if user disabled the checkbox
        if gFlags.save_data_enabled 
            set(handles.EnableOutputFilesBox,'Value',1);
            disp('error - data aquisition is in progress');
            warndlg('error - data aquisition is in progress');
        else
            gFlags.out_files_enabled = false;                      % disable output to files
            set(handles.RootFileNameText,'Enable','on');           % enable editing of the text field

            fclose(log_file_handle)                                %#ok<PRTCAL> % close the log file 
        end
    end
end

function RootFileNameText_KeyPressFcn(~, eventdata, handles)                %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        uicontrol(handles.EnableOutputFilesBox);
        pause(0.1);
        set(handles.EnableOutputFilesBox,'Value',true);
        EnableOutputFilesBox_Callback([],[], handles);
    end
end

function StartEventLog
    % save the basic running parameters to the log file
    global tic_time;              % time of main timer init
    global gAndor;                % global camera struct
    global gFunctionGenerator;    % global function generator struct


    LogEvent(['tic_time - ',num2str(tic_time,'%f')]);
    LogEvent(['Exposure - ',num2str(gAndor.validKinTime,'%f')]);
    LogEvent(['EMGain - ',num2str(gAndor.EMGain)]);
    LogEvent(['FrameSize (Width x Hight) - ',num2str(gAndor.imWidth),' x ',num2str(gAndor.imHeight)]);
    
    LogEvent([                                      ...
      'Function Generator Parameters - ',           ...
      num2str(gFunctionGenerator.Frequency),'KHz ', ...
      num2str(gFunctionGenerator.Amplitude),'V ',   ...
      gFunctionGenerator.Function,' ',              ...
      gFunctionGenerator.TriggerMode,' ',           ...
      gFunctionGenerator.TriggerSource,' ',         ...
      '#',num2str(gFunctionGenerator.BurstCount),   ...
      ]);
    
    LogEvent([
      'Channel 2 Parameters - ',                        ...
      num2str(gFunctionGenerator.Ch2_Frequency),'KHz ', ...
      num2str(gFunctionGenerator.Ch2_Amplitude),'V ',   ...
      gFunctionGenerator.Ch2_Function,' ',              ...
      gFunctionGenerator.Ch2_TriggerMode,' ',           ...
      gFunctionGenerator.Ch2_TriggerSource,' ',         ...
      '#',num2str(gFunctionGenerator.Ch2_BurstCount),   ...      
      ]);
end

function LogEvent(event_text)
    % add an event to the log file
    global log_file_handle;      % handle to log file

    if log_file_handle == -1
        disp('error - log file is not open');
        warndlg('error - log file is not open');
    else
        log_toc = toc;                                            % get event time
        fprintf(log_file_handle, '%f - %s\n', log_toc, event_text); % print the event to file
    end
end

function LogEventButton_Callback(~, ~, handles)
    event_text = get(handles.LogEventText,'String');
    LogEvent(['User - ',event_text]);
end

function LogEventText_KeyPressFcn(~, eventdata, handles)                    %#ok<DEFNU>
    if strcmp(eventdata.Key,'return')
        set(handles.LogEventButton,'Enable','off');
        pause(0.1);
        set(handles.LogEventButton,'Enable','on');
        LogEventButton_Callback([],[], handles);
    end
end

%--------------------------------------------------------------------------
% Other Functions
%--------------------------------------------------------------------------

function BreakPointButton_Callback(~,~,handles)                             %#ok<INUSD,DEFNU>
    keyboard;   % breakpoint
end

function gong(vol,frq,dur)
    % gong: sounds gong
    % by John Gooden - The Netherlands
    % 2007
    % 
    % call gong
    % call gong(vol)
    % call gong(vol,frq)
    % call gong(vol,frq,dur)
    %
    % input arguments (optional, if 0 then default taken)
    % vol = volume (default = 1)
    % frq = base frequency (default = 440 Hz)
    % dur = duration (default = 1 s)

    fb  = 440;
    td  = 1;
    vl  = 1;
    if nargin>=1
        if vol>0 
            vl = vol; 
        end
    end
    if nargin>=2
        if frq>0 
            fb = frq; 
        end
    end
    if nargin>=3
        if dur>0 
            td = dur; 
        end
    end

    t   =[0:8192*td]'/8192;                                                 %#ok<NBRAK>
    env = exp(-5*t/td);
    f   = fb;
    vol = 0.3*vl;
    tpft = 2*pi*f*t;
    sl  = sin(tpft)+0.1*sin(2*tpft)+0.3*sin(3*tpft);
    sl  = vol*sl;
    sr  = [sl(100:end);sl(1:99)];
    vl  = cos(20*t);
    vr  = 1-vl;
    y(:,1) = vl.*env.*sl;
    y(:,2) = vr.*env.*sr;

    sound(y)
end

function FreezeYlimBox_Callback(~, ~, handles)
    global frozen_ylim;            % frozen YLim for selected ROI plot
    
    toggle_state = get(handles.FreezeYlimBox,'Value');
    if toggle_state                                           % if user enabled the checkbox
        % disable competing ManualYlim checkbox
        set(handles.ManualYlimBox,'Value',false);
        ManualYlimBox_Callback([],[],handles);
        
        frozen_ylim = get(handles.axes_left,'YLim');
    else                                                      % if user disabled the checkbox
        frozen_ylim = [0,1];
    end
end

function ManualYlimBox_Callback(~, ~, handles)
    global manual_ylim;            % manual YLim for selected ROI plot

    toggle_state = get(handles.ManualYlimBox,'Value');
    if toggle_state                                           % if user enabled the checkbox
        MinYlim = str2double(get(handles.MinYlimText,'String'));
        MaxYlim = str2double(get(handles.MaxYlimText,'String'));
        
        if isempty(MinYlim) || isnan(MinYlim) ...
        || isempty(MaxYlim) || isnan(MaxYlim) ...
        || MaxYlim <= MinYlim
            disp('error - illegal manual YLim parameters');
            warndlg('error - illegal manual YLim parameters');
            
            set(handles.ManualYlimBox,'Value',false);
        else        
            % disable competing FreezeYlim checkbox
            set(handles.FreezeYlimBox,'Value',false);
            FreezeYlimBox_Callback([],[],handles);
            
            set(handles.MinYlimText,'Enable','off');     % disable editing of the text field
            set(handles.MaxYlimText,'Enable','off');     % disable editing of the text field
            
            manual_ylim = [MinYlim,MaxYlim];
        end
    else                                                      % if user disabled the checkbox
        set(handles.MinYlimText,'Enable','on');          % enable editing of the text field
        set(handles.MaxYlimText,'Enable','on');          % enable editing of the text field
    end
end

%--------------------------------------------------------------------------
% Unmodified GUIDE Generated Functions
%--------------------------------------------------------------------------
function varargout = AA_OutputFcn(hObject, eventdata, handles)              %#ok<INUSL>
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    % --- Outputs from this function are returned to the command line.
    varargout{1} = handles.output;
end

%--------------------------------------------------------------------------
% Tektronix THS720 Oscilloscope Control Functions
%--------------------------------------------------------------------------

function InitScopeButton_Callback(~, ~, handles)                            %#ok<DEFNU>
    global gScope;    % global oscilloscope struct
    global gFlags;    % global control flags struct
    
    scope_id = 'IDTEK/THS720,CF:91.1CT,FV:v1.03';
    
    % animate the button
    set(handles.InitScopeButton,'Enable','off');
    drawnow;

    gScope.handle = instrfind('Type', 'serial','Port','COM3');
    if isempty(gScope.handle)
        gScope.handle = serial('COM3','BaudRate',9600);
    else
        fclose(gScope.handle);
    end
    
    % define but disable output callback use
    gScope.GetScopeMeasurmentsAsyncCallback_flag = false;
    gScope.handle.BytesAvailableFcn              = {@GetScopeMeasurmentsAsyncCallback,handles};
    gScope.handle.BytesAvailableFcnMode          = 'terminator';   
    
    % open connection to scope
    fopen(gScope.handle);                                                   
    
    % clear error buffer
    fprintf(gScope.handle,'*ESR?');fscanf(gScope.handle);
    
    % check scope identity string
    fprintf(gScope.handle, 'ID?');               
    scope_identity_reply = fscanf(gScope.handle,'%s');
    
    if ~strcmp(scope_id,scope_identity_reply)
        disp('error - can not connect to tektronix scope');
        warndlg('error - can not connect to tektronix scope');
        
        fclose(gScope.handle);
        gScope.handle = [];
    else
        command_idx = 1;
        command_list{command_idx} = 'RECAll:SETUp FACtory';                             command_idx=command_idx+1;  % load factory default settings

        % amplifier voltage channel settings
        amp_ch = ['CH',num2str(gScope.voltage_ch)];
        command_list{command_idx} = ['SELect:',amp_ch,' ON'];                           command_idx=command_idx+1;  % turn on channel 
        command_list{command_idx} = [amp_ch,':PROBe:VOLTSCALE 1'];                      command_idx=command_idx+1;  % set probe multiplier to x1
        command_list{command_idx} = [amp_ch,':SCAle ',num2str(gScope.voltage_scale)];   command_idx=command_idx+1;  % set horizontal scale

        command_list{command_idx} = 'MEASUrement:MEAS1:STATE ON';                       command_idx=command_idx+1;
        command_list{command_idx} = ['MEASUrement:MEAS1:SOUrce ',amp_ch];               command_idx=command_idx+1;
        command_list{command_idx} = 'MEASUrement:MEAS1:TYPe RMS';                       command_idx=command_idx+1;  % measure RMS
    
        % current probe channel settings
        probe_ch = ['CH',num2str(gScope.current_ch)];
        command_list{command_idx} = ['SELect:',probe_ch,' ON'];                          command_idx=command_idx+1;  % turn on channel 
        command_list{command_idx} = [probe_ch,':PROBe:VOLTSCALE 1'];                     command_idx=command_idx+1;  % set probe multiplier to x1
        command_list{command_idx} = [probe_ch,':SCAle ',num2str(gScope.current_scale)];  command_idx=command_idx+1;  % set horizontal scale

        command_list{command_idx} = 'MEASUrement:MEAS2:STATE ON';                        command_idx=command_idx+1;
        command_list{command_idx} = ['MEASUrement:MEAS2:SOUrce ',probe_ch];              command_idx=command_idx+1;
        command_list{command_idx} = 'MEASUrement:MEAS2:TYPe RMS';                        command_idx=command_idx+1;  % measure RMS
        
        % general settings
        command_list{command_idx} = 'TRIGger:MAIn:MODe NORMal';                                  command_idx=command_idx+1;  % enable triggered aquisition
        command_list{command_idx} = ['TRIGger:MAIn:EDGE:SOUrce CH',num2str(gScope.trig_source)]; command_idx=command_idx+1;  % set trigger source channel
        command_list{command_idx} = ['TRIGger:MAIn:LEVel ',num2str(gScope.trig_level)];          command_idx=command_idx+1;  % set trigger threshold
        command_list{command_idx} = 'ACQUIRE:STOPAfter RUNSTop';                                 command_idx=command_idx+1;  % set aquisition not to stop after each aquisition
        
        command_list{command_idx} = 'HORizontal:MODe DELAYEd';                                   command_idx=command_idx+1;
        command_list{command_idx} = ['HORizontal:DELay:SCAle ',num2str(gScope.horiz_scale)];     command_idx=command_idx+1;  % horizontal scale with magnification (10x) 500ns
        command_list{command_idx} = ['HORizontal:DELay:TIMe ',num2str(gScope.trig_delay)];       command_idx=command_idx+1;  % set trigger to aquisition delay

        % measurment command batch
        command_list{command_idx} = ['*DDT #262',                     ...   % batch is 62 charecters long (length number has 2 digits)
                                     'MEASUrement:IMMed:TYPe RMS',';',...
                                     'SOUrce ',amp_ch,            ';',...
                                     'VALue?',                    ';',...
                                     'SOUrce ',probe_ch,          ';',...
                                     'VALue?'];                                                  command_idx=command_idx+1;
                                 
        % make sure the scope is not waiting for a trigger
        command_list{command_idx} = 'TRIGger FORCe';                                             command_idx=command_idx+1;
        
        
        % run scope commands
        for command_idx = 1:length(command_list)
            RunScopeCommand(command_list{command_idx},false);
            while gScope.handle.BytesToOutput ~= 0                          % wait for output buffer to empty before issuing the next command
                pause(0.01);
            end
        end
    end    
    
    % indicate that initialization is done
    set(handles.InitScopeButton,'Enable','on');     % animate the button
    gong(1000,3000,0.3);                            % sound a beep
    
    % enable scope GUI elements
    set(handles.UseScopeBox,'Enable','on');
    
    if gFlags.out_files_enabled
        LogEvent('Scope - initialized');
    end    
end

function WaitOnScopeAquisitionState(wanted_flag)
	global gScope;    % global oscilloscope struct
    global gFlags;    % global control flags struct
    
    wait_time_limit = 0.5;       % (s)
    pause_time      = 0.01;      % (s)

    % check that the scope is initialized
    if isempty(gScope.handle)
        disp('error - scope not initialized');
        warndlg('error - scope not initialized');
        if gFlags.out_files_enabled
            LogEvent('error - scope not initialized');
        end     
    % scope is initialized
    else
        current_flag = ~wanted_flag;
        waited_time = 0;

        while current_flag ~= wanted_flag && waited_time < wait_time_limit
            ret_str = RunScopeCommand('ACQuire:STATE?',true);
            if isempty(strfind(ret_str,'1'))
                current_flag = false;
            else
                current_flag = true;
            end
            pause(pause_time);
            waited_time = waited_time + pause_time;
        end

        if waited_time >= wait_time_limit
            disp('error - timeout waiting for scope aquisition state');
            warndlg('error - timeout waiting for scope aquisition state');
        end
    end
end

function GetScopeMeasurmentsAsync(handles)
	global gScope;    % global oscilloscope struct
    global gFlags;    % global control flags struct
    
    % check that the scope is initialized
    if isempty(gScope.handle)
        disp('error - scope not initialized');
        warndlg('error - scope not initialized');
        if gFlags.out_files_enabled
            LogEvent('error - scope not initialized');
        end   
    else
        % wait for scope aquisition to finish (asynchronously)
        fprintf(gScope.handle, '*OPC');     % this commands turns on a marker when aquisition is done
        gScope.OPC_waited_time = 0;         % initialize timeout counter
        gScope.OPC_error_flag = false;      % initialize error flag
        ScopeWaitAsyncOPC([],[],handles);   % asynchronously wait for the marker
    end
end

function ScopeWaitAsyncOPC(~,~,handles)
    % these commands nee to be run before calling this function
    % fprintf(gScope.handle, '*OPC');
    % gScope.OPC_waited_time = 0;
    % gScope.OPC_error_flag = false;
    
    global gScope;    % global oscilloscope struct

    wait_time_limit = 1.0;      % timout (s)
    timer_time      = 0.1;      % time between iteration of this function (s)
 
    % get SESR register LSB
    fprintf(gScope.handle, '*ESR?');
    response_str     = fscanf(gScope.handle);
    response_str_bin = dec2bin(str2double(response_str));
    response_lsb     = str2double(response_str_bin(end));
    
    % if not done yet
    if response_lsb == 0
        % if timeout
        if gScope.OPC_waited_time > wait_time_limit
            gScope.OPC_error_flag = true;               % enable error flag
            fprintf(gScope.handle, 'TRIGger FORCe');    % trigger the scope
        end
        
        fprintf(gScope.handle, '*OPC');
        
        % prepare timer object for reruning this function
        if ~isfield(gScope,'OPC_timer')
            timer_open_slot = 1;
            new_timer_flag = true;
        elseif isempty(gScope.OPC_timer)
            gScope = rmfield(gScope,'OPC_timer');
            timer_open_slot = 1;
            new_timer_flag = true;
        else
            % find available timer object or create a new one
            timer_open_slot = NaN;
            timer_num = length(gScope.OPC_timer);
            for curr_timer_idx=1:timer_num
                if isvalid(gScope.OPC_timer(curr_timer_idx))
                    timer_status = gScope.OPC_timer(curr_timer_idx).Running;
                    if strcmp(timer_status,'off')
                        timer_open_slot = curr_timer_idx;
                        new_timer_flag  = false;
                    end
                else
                    timer_open_slot = curr_timer_idx;
                    new_timer_flag  = true;    
                end
            end

            if isnan(timer_open_slot)
                timer_open_slot = timer_num+1;
                new_timer_flag  = true; 
            end
        end
        
        if new_timer_flag
            gScope.OPC_timer(timer_open_slot) = timer('Name',          'OPC_timer',              ...
                                                      'ExecutionMode', 'singleShot',             ...
                                                      'StartDelay',    timer_time,               ...
                                                      'BusyMode',      'queue',                  ...
                                                      'TimerFcn',      {@ScopeWaitAsyncOPC,handles});           
        end

        % update timeout counter
        gScope.OPC_waited_time =  gScope.OPC_waited_time + timer_time;
        
        % start timer
        start(gScope.OPC_timer(timer_open_slot));
    % if done waiting
    elseif response_lsb == 1
        % run scope measurment (asynchronously)
        gScope.GetScopeMeasurmentsAsyncCallback_flag = true;                % enable callback for asynchronous execution
        fprintf(gScope.handle, '*TRG');                                     % run measurement batch
    else
        disp('error - illegal OPC response');
        warndlg('error - illegal OPC response');
        if gFlags.out_files_enabled
            LogEvent('error - illegal OPC response');
        end
    end
end

function GetScopeMeasurmentsAsyncCallback(~,~,handles)
	global gScope;    % global oscilloscope struct
    global gFlags;    % global control flags struct
    
    % check if asynchronous execution is enabled
    if gScope.GetScopeMeasurmentsAsyncCallback_flag
        % so that this function does not run again immediately
        gScope.GetScopeMeasurmentsAsyncCallback_flag = false;

        if ~gScope.OPC_error_flag
            % get measurement results
            meas_ret_str = fscanf(gScope.handle);

            % check for returned error
            fprintf(gScope.handle,'*ESR?');         
            ret_code = fscanf(gScope.handle);
            if(str2double(ret_code) > 1)
                fprintf(gScope.handle,'ALLEV?');
                error_ret = fscanf(gScope.handle);

                disp(['error - running scope measurement - ',error_ret]);
                warndlg(['error - running scope measurement - ',error_ret]);
                if gFlags.out_files_enabled
                    LogEvent(['error - running scope measurement - ',error_ret]);
                end
            end

            % parse measurement results
            found_idx = strfind(meas_ret_str,':MEASUREMENT:IMMED:VALUE ');

            if length(found_idx) ~= 2
                disp(['error - scope measurement returned illegal string - ',meas_ret_str]);
                warndlg(['error - scope measurement returned illegal string - ',meas_ret_str]);

                if gFlags.out_files_enabled
                    LogEvent('Scope - ERROR');
                end
            else
                amp_rms   = num2str(str2double(meas_ret_str(found_idx(1)+24:found_idx(2)-2)),4);
                probe_rms = num2str(str2double(meas_ret_str(found_idx(2)+24:end)),4);

                VA_rms = num2str((str2double(amp_rms) * str2double(probe_rms)),4);

                % write measurements in GUI and log
                set(handles.ScopeVText,'String',amp_rms);
                set(handles.ScopeAText,'String',probe_rms);
                set(handles.ScopeVAText,'String',VA_rms);

                if gFlags.out_files_enabled
                    LogEvent(['Scope - V:',amp_rms,' A:',probe_rms]);
                end
            end
        else           
            % reset error flag
            gScope.OPC_error_flag = false;
            
            % error waiting for aquisition to finish
            disp('error - timeout waiting for scope to finish aquisition (check if generator ch1 is on)');
            warndlg('error - timeout waiting for scope to finish aquisition (check if generator ch1 is on)');
            if gFlags.out_files_enabled
                LogEvent('error - timeout waiting for scope to finish aquisition (check if generator ch1 is on)');
                LogEvent('Scope - V:ERROR A:ERROR');
            end
        end
        
        % enable trigger button
        set(handles.TriggerButton,'Enable','on');
    end
end

function SetScopeVerticalScale()
    global gFunctionGenerator;      % global function generator struct
    global gScope;                  % global oscilloscope struct
 
   % choose amp voltage scale (values correct for yellow amp with gain at 5 turns)
    if     gFunctionGenerator.Amplitude < 0.060
        gScope.voltage_scale = 0.100;
    elseif gFunctionGenerator.Amplitude < 0.150
        gScope.voltage_scale = 0.200;
    elseif gFunctionGenerator.Amplitude < 0.300
        gScope.voltage_scale = 0.500;     
    elseif gFunctionGenerator.Amplitude < 0.700
        gScope.voltage_scale = 1.000;     
    elseif gFunctionGenerator.Amplitude < 1.500
        gScope.voltage_scale = 2.000;    
    elseif gFunctionGenerator.Amplitude < 3.000
        gScope.voltage_scale = 5.000;  
    else
        gScope.voltage_scale = 5.000;
    end

    RunScopeCommand(['CH',num2str(gScope.voltage_ch),':SCAle ',num2str(gScope.voltage_scale)],false);
    
    % choose current probe scale (values correct for yellow amp with gain at 5 turns)
    if     gFunctionGenerator.Amplitude < 0.020
        gScope.current_scale = 0.010;
    elseif gFunctionGenerator.Amplitude < 0.080
        gScope.current_scale = 0.020;
    elseif gFunctionGenerator.Amplitude < 0.200
        gScope.current_scale = 0.050;  
    elseif gFunctionGenerator.Amplitude < 0.400
        gScope.current_scale = 0.100;    
    elseif gFunctionGenerator.Amplitude < 0.800
        gScope.current_scale = 0.200;    
    elseif gFunctionGenerator.Amplitude < 2.000
       gScope.current_scale = 0.500;    
    elseif gFunctionGenerator.Amplitude < 4.000
        gScope.current_scale = 1.000;   
    else
        gScope.current_scale = 2.000;
    end
     
    RunScopeCommand(['CH',num2str(gScope.current_ch),':SCAle ',num2str(gScope.current_scale)],false);
    
    % values for leysop amp
    %{
     
    choose amp voltage scale (values correct for leysop amp)
    if     gFunctionGenerator.Amplitude < 0.025
        gScope.voltage_scale = 0.500;
    elseif gFunctionGenerator.Amplitude < 0.050
        gScope.voltage_scale = 1.000;
    elseif gFunctionGenerator.Amplitude < 0.175
        gScope.voltage_scale = 2.000;
    elseif gFunctionGenerator.Amplitude < 0.250
        gScope.voltage_scale = 5.000;
    elseif gFunctionGenerator.Amplitude < 0.500
        gScope.voltage_scale = 10.000;
    elseif gFunctionGenerator.Amplitude < 1.500
        gScope.voltage_scale = 20.000;
    else
        gScope.voltage_scale = 50.000;
    end
    
    RunScopeCommand(['CH',num2str(gScope.voltage_ch),':SCAle ',num2str(gScope.voltage_scale)],false);
    
    % choose current probe scale
    if     gFunctionGenerator.Amplitude < 0.175
        gScope.current_scale = 0.005;
    elseif gFunctionGenerator.Amplitude < 0.250
        gScope.current_scale = 0.010;
    elseif gFunctionGenerator.Amplitude < 1.000
        gScope.current_scale = 0.020;
    elseif gFunctionGenerator.Amplitude < 2.000
        gScope.current_scale = 0.050;
    else
        gScope.current_scale = 0.100;
    end
     
    RunScopeCommand(['CH',num2str(gScope.current_ch),':SCAle ',num2str(gScope.current_scale)],false);
    %}  
end

function response_str = RunScopeCommand(command_str,get_response_flag)
    global gFlags;    % global control flags struct
	global gScope;    % global oscilloscope struct
    
    % check that the scope is initialized
    if isempty(gScope.handle)
        disp('error - scope not initialized');
        warndlg('error - scope not initialized');
        if gFlags.out_files_enabled
            LogEvent('error - scope not initialized');
        end
    else
        % clear response buffer
        while gScope.handle.BytesAvailable
            fscanf(gScope.handle);
        end
        
        % send command
        fprintf(gScope.handle,command_str);
        
        % get response
        if get_response_flag
            response_str = fscanf(gScope.handle);
        else
            response_str = [];
        end

        % check for returned error
        fprintf(gScope.handle,'*ESR?');         
        ret_code = fscanf(gScope.handle);
        if(str2double(ret_code) > 1)
            fprintf(gScope.handle,'ALLEV?');
            error_ret = fscanf(gScope.handle);

            error_str = [command_str,' - ',error_ret];

            disp(['error - running scope command - ',error_str]);
            warndlg(['error - running scope command - ',error_str]);
            if gFlags.out_files_enabled
                LogEvent(['error - running scope command - ',error_str]);
            end
        end
    end
end

function UseScopeBox_Callback(~,~,handles)                                  %#ok<DEFNU>
    global gScope;    % global oscilloscope struct
    global gFlags;                 % global control flags struct
    global gTrigger;               % global trigger struct
    
    if get(handles.UseScopeBox,'Value')                 % if the checkbox is checked
        gTrigger.use_scope_flag = true;
        
        % enable scope GUI elements
        set(handles.ScopeVLabel, 'Enable','on');
        set(handles.ScopeVText,  'Enable','on');
        set(handles.ScopeALabel, 'Enable','on');
        set(handles.ScopeAText,  'Enable','on');        
        set(handles.ScopeVALabel,'Enable','on');
        set(handles.ScopeVAText, 'Enable','on');
        
        % set aquisition to stop after each aquisition
        command_text = 'ACQUIRE:STOPAfter SEQuence';    
        RunScopeCommand(command_text,false);
        while gScope.handle.BytesToOutput ~= 0          % wait for output buffer to empty before issuing the next command
            pause(0.01);
        end

        if gFlags.out_files_enabled
            LogEvent('Trigger - Use Scope Enabled');
        end
    else                                                % if the checkbox is unchecked
        gTrigger.use_scope_flag = false;
        
        % disable scope GUI elements
        set(handles.ScopeVLabel, 'Enable','off');
        set(handles.ScopeVText,  'Enable','off');
        set(handles.ScopeALabel, 'Enable','off');
        set(handles.ScopeAText,  'Enable','off');        
        set(handles.ScopeVALabel,'Enable','off');
        set(handles.ScopeVAText, 'Enable','off');

        % set aquisition to not stop after each aquisition
        command_text = 'ACQUIRE:STOPAfter RUNSTop';
        RunScopeCommand(command_text,false);
        while gScope.handle.BytesToOutput ~= 0          % wait for output buffer to empty before issuing the next command
            pause(0.01);
        end
        
        % release the scope from HOLD mode
        command_text = 'ACQUIRE:STATE RUN';
        RunScopeCommand(command_text,false);
        while gScope.handle.BytesToOutput ~= 0          % wait for output buffer to empty before issuing the next command
            pause(0.01);
        end
        
        if gFlags.out_files_enabled
            LogEvent('Trigger - Use Scope Disabled');
        end
    end
end

%--------------------------------------------------------------------------
% Error Handeling Functions
%--------------------------------------------------------------------------

% --- Executes on button press in trigger_button_reset.
function trigger_button_reset_Callback(~,~,handles)                       %#ok<DEFNU>
    set(handles.TriggerButton,'Enable','on');
end

% --- Executes on button press in startpreview_button_reset.
function startpreview_button_reset_Callback(~,~,handles)                  %#ok<DEFNU>
    set(handles.StartPreviewButton,'Enable','on');
end
