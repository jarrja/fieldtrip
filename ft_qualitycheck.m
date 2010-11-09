function ft_qualitycheck(varargin)

% FT_QUALITYCHECK computes quality and quantity features of MEG recordings and
% exports those to both .PNG and .PDF files.
%
% This function is specific for the data recorded with the CTF MEG system
% at the Donders Centre for Cognitive Neuroimaging, Nijmegen, The
% Netherlands.
%
% Input should be '*/*.ds'.
%
% Copyright (C) 2010-2011, Arjen Stolk, Bram Daams
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.

try
    %% DEFINE THE SEGMENTS; 10 second trials
    tic
    cfg                         = [];
    cfg.dataset                 = varargin{1};
    cfg.trialdef.eventtype      = 'trial';
    cfg.trialdef.prestim        = 0;
    cfg.trialdef.poststim       = 10; % 10 seconds of data
    cfg                         = ft_definetrial(cfg);
    
    %% READ HISTORY FILE in order to extract date & time
    logfile = strcat(cfg.datafile(1:end-5),'.hist');
    fileline = 0;
    fid = fopen(logfile,'r');
    while fileline >= 0
        fileline = fgets(fid);
        if ~isempty(findstr(fileline,'Collection started'))
            startdate = sscanf(fileline(findstr(fileline,'Collection started:'):end),'Collection started: %s');
            starttime = sscanf(fileline(findstr(fileline,startdate):end),strcat(startdate, '%s'));
        end
        if ~isempty(findstr(fileline,'Collection stopped'))
            stopdate = sscanf(fileline(findstr(fileline,'Collection stopped:'):end),'Collection stopped: %s');
            stoptime = sscanf(fileline(findstr(fileline,stopdate):end),strcat(stopdate, '%s'));
        end
        if ~isempty(findstr(fileline,'Dataset name'))
            datasetname = sscanf(fileline(findstr(fileline,'Dataset name'):end),'Dataset name %s');
        end
        if ~isempty(findstr(fileline,'Sample rate'))
            fsample = sscanf(fileline(findstr(fileline,'Sample rate:'):end),'Sample rate: %s');
        end
    end
    vec = datevec(startdate);
    year = vec(1);
    month = startdate(4:6);
    day = vec(3);
    start = datevec(starttime);
    stop = datevec(stoptime);
    startmins = start(4)*60 + start(5);
    stopmins = stop(4)*60 + stop(5);
    
    %% TRIAL LOOP; preproc trial by trial
    ntrials = size(cfg.trl,1);
    for t = 1:ntrials
        fprintf('analyzing trial %s of %s \n', num2str(t), num2str(ntrials));
        
        % preproc raw
        cfgpreproc                  = cfg;
        cfgpreproc.trl              = cfg.trl(t,:);
        data                        = ft_preprocessing(cfgpreproc); clear cfgpreproc;
        
        % jump artefact counter
        jumpthreshold               = 1e-10;
        chans                       = ft_channelselection('MEG', data.label);
        rawindx                     = match_str(data.label, chans);
        nchans                      = length(chans);
        for c = 1:nchans
            jumps(c,t)              = length(find(diff(data.trial{1,1}(rawindx(c),:)) > jumpthreshold));
        end
        
        refchans                    = ft_channelselection('MEGREF', data.label);
        refindx                     = match_str(data.label, refchans);
        nrefs                       = length(refchans);
        for c = 1:nrefs
            refjumps(c,t)           = length(find(diff(data.trial{1,1}(refindx(c),:)) > jumpthreshold));
        end
        
        % determine the minima and maxima
        minima                      = min((data.trial{1,1}(rawindx,1)));
        lowerbound(t)               = min(minima); clear minima;
        maxima                      = max((data.trial{1,1}(rawindx,1)));
        upperbound(t)               = max(maxima); clear maxima;
        
        % determine noise
        freq                        = spectralestimate(data);
        spec(t,:,:)                 = findpower(0.5, 100, freq);
        lowfreqnoise(t)             = mean(mean(findpower(0.1, 2, freq)));
        linenoise_prefilt           = mean(findpower(49, 51, freq),2); clear freq;
        
        % preproc with noise filter
        cfgpreproc2.dftfilter       = 'yes'; % notch filter to filter out 50Hz
        data2                       = ft_preprocessing(cfgpreproc2, data); clear data;
        
        % determine noise
        freq2                       = spectralestimate(data2); clear data2;
        linenoise_postfilt          = mean(findpower(49, 51, freq2),2); clear freq2;
        
        % relative difference pre vs post dft filtered data
        linenoise_mean(t)           = ...
            mean((linenoise_prefilt-linenoise_postfilt)./linenoise_postfilt);
        linenoise_std(t)            = ...
            std((linenoise_prefilt-linenoise_postfilt)./linenoise_postfilt);
        clear linenoise_prefilt; clear linenoise_postfilt;
        
        toc
    end % end of trial loop
    
    %% VISUALIZE
    % Parent figure
    h.MainFigure = figure(...
        'MenuBar','none',...
        'Name','ft_qualitycheck',...
        'Units','normalized',...
        'color','white',...
        'Position',[0.01 0.01 .99 .99]); % nearly fullscreen
    
    h.MainText = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',startdate,...
        'Backgroundcolor','white',...
        'Position',[.05 .96 .1 .02]);
    
    h.MainText2 = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Topographic artefact distribution',...
        'Backgroundcolor','white',...
        'Position',[.02 .61 .22 .02]);
    
    h.MainText3 = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Mean powerspectrum',...
        'Backgroundcolor','white',...
        'Position',[.4 .3 .15 .02]);
    
    h.MainText4 = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Timeplots',...
        'Backgroundcolor','white',...
        'Position',[.5 .96 .08 .02]);
    
    h.MainText5 = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Quantification',...
        'Backgroundcolor','white',...
        'Position',[.8 .3 .1 .02]);
    
    % plot the top 5 artefact chans
    [cnts, indx] = sort(sum(jumps,2));
    artchans = chans(indx(end:-1:end-4));
    h.MainText6 = uicontrol(...
        'Parent',h.MainFigure,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',[artchans(1:end)],...
        'Backgroundcolor','white',...
        'Position',[.2 .31 .05 .12]);
        
    % Time & date
    h.DatePanel = uipanel(...
        'Parent',h.MainFigure,...
        'Units','normalized',...
        'Backgroundcolor','white',...
        'Position',[.01 .65 .25 .32]); %'Title',startdate,...
    
    h.DayAxes = axes(...
        'Parent',h.DatePanel,...
        'Units','normalized',...
        'color','white',...
        'PlotBoxAspectRatioMode','manual',...
        'Position',[.01 .3 .49 .6]);
    
    h.MinuteAxes = axes(...
        'Parent',h.DatePanel,...
        'Units','normalized',...
        'color','white',...
        'PlotBoxAspectRatio',[1 1 1],...
        'Position',[.50 .3 .49 .6]);
    
    h.DataText = uicontrol(...
        'Parent',h.DatePanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',datasetname,...
        'Backgroundcolor','white',...
        'Position',[.01 .2 .99 .1]);
    
    h.TimeText = uicontrol(...
        'Parent',h.DatePanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',[starttime ' - ' stoptime],...
        'Backgroundcolor','white',...
        'Position',[.01 .1 .99 .1]);
    
    h.DataText2 = uicontrol(...
        'Parent',h.DatePanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',['fs: ' fsample ', nchans: ' num2str(nchans)],...
        'Backgroundcolor','white',...
        'Position',[.01 .0 .99 .1]);
    
    % Topo artefact plot
    h.TopoPanel = uipanel(...
        'Parent',h.MainFigure,...
        'Units','normalized',...
        'Backgroundcolor','white',...
        'Position',[.01 .01 .25 .61]); %'Title','Topographic artefact distribution',...
    
    h.TopoREF = axes(...
        'Parent',h.TopoPanel,...
        'color','white',...
        'Position',[0.01 0.72 0.99 0.25]);% 'DataAspectRatio',[1 1 1],...
    
    h.TopoMEG = axes(...
        'Parent',h.TopoPanel,...
        'color','white',...
        'Position',[0.01 0.01 0.99 0.6]);
    
    % Mean spectrum
    h.SpectrumPanel = uipanel(...
        'Parent',h.MainFigure,...
        'Units','normalized',...
        'Backgroundcolor','white',...
        'Position',[.28 .01 .4 .3]); %'Title','Mean powerspectrum',...
    
    h.SpectrumAxes = axes(...
        'Parent',h.SpectrumPanel,...
        'color','white',...
        'Position',[.13 .17 .85 .73]);
    
    % Time plots
    h.SignalPanel = uipanel(...
        'Parent',h.MainFigure,...
        'Units','normalized',...
        'Backgroundcolor','white',...
        'Position',[.28 .34 .71 .63]); %'Title','Timeplots',...
    
    h.SignalAxes = axes(...
        'Parent',h.SignalPanel,...
        'Units','normalized',...
        'color','white',...
        'Position',[.06 .7 .9 .25]);
    
    h.LinenoiseAxes = axes(...
        'Parent',h.SignalPanel,...
        'Units','normalized',...
        'color','white',...
        'Position',[.06 .4 .9 .25]);
    
    h.LowfreqnoiseAxes = axes(...
        'Parent',h.SignalPanel,...
        'Units','normalized',...
        'color','white',...
        'Position',[.06 .1 .9 .25]);
    
    % Quick overview quantification sliders
    h.QuantityPanel = uipanel(...
        'Parent',h.MainFigure,...
        'Units','normalized',...
        'Backgroundcolor','white',...
        'Position',[.7 .01 .29 .3]); %'Title','Quantification',...
    
    h.LineNoiseSlider = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','slider',...
        'Units','normalized',...
        'Value',round(mean(linenoise_mean)),...
        'Min',0,...
        'Max',100,...
        'Position',[.1 .35 .8 .2],...
        'String','Line noise');
    
    h.LineNoiseText = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Line noise [%]',...
        'Backgroundcolor','white',...
        'Position',[.2 .55 .6 .07]);
    
    h.LineNoiseTextMin = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.LineNoiseSlider,'Min'),...
        'Backgroundcolor','white',...
        'Position',[.0 .35 .1 .2]);
    
    h.LineNoiseTextMax = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.LineNoiseSlider,'Max'),...
        'Backgroundcolor','white',...
        'Position',[.9 .35 .1 .2]);
    
    h.LowFreqSlider = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','slider',...
        'Units','normalized',...
        'Value',mean(lowfreqnoise),...
        'Min',0,...
        'Max',1e-20,...
        'SliderStep',[1e-23 1e-22],...
        'Position',[.1 .0 .8 .2],...
        'String','Low freq noise');
    
    h.LowFreqText = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Low freq power [T^2]' ,...
        'Backgroundcolor','white',...
        'Position',[.2 .2 .6 .07]);
    
    h.LowFreqTextMin = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.LowFreqSlider,'Min'),...
        'Backgroundcolor','white',...
        'Position',[.0 .0 .1 .2]);
    
    h.LowFreqTextMax = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.LowFreqSlider,'Max'),...
        'Backgroundcolor','white',...
        'Position',[.9 .0 .1 .2]);
    
    h.ArtifactSlider = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','slider',...
        'Units','normalized',...
        'Value',sum(sum(jumps,2),1)/10,...
        'Min',0,...
        'Max',50,...
        'Position',[.1 .7 .8 .2],...
        'String','Artifacts');
    
    h.ArtifactText = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String','Artifacts [#/10seconds]',...
        'Backgroundcolor','white',...
        'Position',[.2 .9 .6 .07]);
    
    h.ArtifactTextMin = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.ArtifactSlider,'Min'),...
        'Backgroundcolor','white',...
        'Position',[.0 .7 .1 .2]);
    
    h.ArtifactTextMax = uicontrol(...
        'Parent',h.QuantityPanel,...
        'Style','text',...
        'Units','normalized',...
        'FontSize',10,...
        'String',get(h.ArtifactSlider,'Max'),...
        'Backgroundcolor','white',...
        'Position',[.9 .7 .1 .2]);
    
    % plot artefacts on the dewar sensors
    cfg            = [];
    cfg.colorbar   = 'WestOutside';
    cfg.commentpos = 'leftbottom';
    cfg.comment    = 'N artifacts/ 10 seconds';
    cfg.style      = 'straight';
    cfg.layout     = 'CTF275.lay';
    cfg.zlim       = 'maxmin';
    data.label     = chans;
    data.powspctrm = jumps;
    data.dimord    = 'chan_freq';
    data.freq      = 1:size(jumps,2);
    axes(h.TopoMEG);
    ft_topoplotTFR(cfg, data);
    
    % plot artefacts on the reference sensors
    data.label     = refchans;
    data.powspctrm = refjumps;
    axes(h.TopoREF);
    plot_REF(data);
    
    % plot date & time
    pie(h.DayAxes,[31-day day]); % day pie
    title(h.DayAxes,['days/' month]);
    pie(h.MinuteAxes,[24*60-stopmins stopmins-startmins startmins]); % minutes pie
    title(h.MinuteAxes,['minutes/' num2str(day) 'th']);
    
    % plot powerspectrum
    plot(h.SpectrumAxes, .5:1/10:100, squeeze(mean(mean(spec,1),2)),'r','LineWidth',2);
    xlabel(h.SpectrumAxes, 'Frequency [Hz]');
    ylabel(h.SpectrumAxes, 'Power [T^2/Hz]');
    
    % plot lower- and upperbound
    plot(h.SignalAxes, 1:10:length(lowerbound)*10, lowerbound, 1:10:length(upperbound)*10, upperbound, 'LineWidth',3);
    ylabel(h.SignalAxes, 'Amplitude [T]');
    legend(h.SignalAxes,'Minima','Maxima');
    set(h.SignalAxes,'XTick',1:length(upperbound));
    set(h.SignalAxes,'XTickLabel',{});
    
    % plot linenoise
    plot(h.LinenoiseAxes, 1:10:length(linenoise_mean)*10, linenoise_mean, 'LineWidth',3);
    ylabel(h.LinenoiseAxes, '[%]');
    legend(h.LinenoiseAxes, 'Line noise');
    set(h.LinenoiseAxes,'XTick',1:length(linenoise_mean));
    set(h.LinenoiseAxes,'XTickLabel',{});
    
    % plot lowfreqnoise
    plot(h.LowfreqnoiseAxes, 1:10:length(lowfreqnoise)*10, lowfreqnoise, 'LineWidth',3);
    legend(h.LowfreqnoiseAxes, 'Low freq power');
    xlabel(h.LowfreqnoiseAxes, 'Time [seconds]');
    
    %% EXPORT TO .PNG AND .PDF
    exportname = strcat(datasetname(end-10:end-3),'_',starttime([1:2 4:5]));
    set(gcf, 'PaperType', 'a4');
    print(gcf, '-dpng', strcat(exportname,'.png'));
    orient landscape;
    print(gcf, '-dpdf', strcat(exportname,'.pdf'));
    close
catch
    warning('failed to qualitycheck %s \n', varargin{1});
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [freqoutput] = spectralestimate(data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cfgfreq              = [];
cfgfreq.output       = 'pow';
cfgfreq.channel      = 'MEG';
cfgfreq.method       = 'mtmfft';
cfgfreq.taper        = 'hanning';
cfgfreq.foilim       = [0.1 100]; % Fr ~ .1 hz
freqoutput           = ft_freqanalysis(cfgfreq, data);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [power] = findpower(low, high, freqinput)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% replace value with the index of the nearest bin
xmin  = nearest(getsubfield(freqinput, 'freq'), low);
xmax  = nearest(getsubfield(freqinput, 'freq'), high);
% select the freq range
power = freqinput.powspctrm(:,xmin:xmax);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plot_REF(dat)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prepare sensors
cfg            = [];
cfg.layout     = 'CTFREF.lay';
cfg.layout     = ft_prepare_layout(cfg);
cfg.layout     = rmfield(cfg.layout,'outline');

% Select the channels in the data that match with the layout:
[seldat, sellay] = match_str(dat.label, cfg.layout.label);
if isempty(seldat)
    error('labels in data and labels in layout do not match');
end

datavector = dat.powspctrm(seldat);
% Select x and y coordinates and labels of the channels in the data
chanX = cfg.layout.pos(sellay,1);
chanY = cfg.layout.pos(sellay,2);
chanLabels = cfg.layout.label(sellay);

% Plot the sensors without the head
ft_plot_topo(chanX,chanY,datavector,'interpmethod','v4',...
    'interplim','electrodes',...
    'gridscale',67,...
    'isolines',6,...
    'mask',cfg.layout.mask,...
    'style','surf');
hold on; ft_plot_lay(cfg.layout,'box','no','mask',false,'verbose',true);
