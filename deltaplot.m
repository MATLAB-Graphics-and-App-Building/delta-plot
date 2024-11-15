classdef deltaplot < matlab.graphics.chartcontainer.ChartContainer & ...
        matlab.graphics.chartcontainer.mixin.Legend
    %DELTAPLOT Plot line segments showing the difference between
    %   two values for multiple items.
    %
    %   DELTAPLOT(X1, X2) displays a horizontal line segment for
    %   each element in X1, spanning the two X-values and
    %   positioned vertically by index value.
    %
    %   DELTAPLOT(X1, Y1, X2, Y2) displays a line segment for
    %   each element in X1, spanning from the coordinate (X1, Y1)
    %   to (X2, Y2).
    %
    %   DELTAPLOT(___, names) specifies ItemLabels for each line
    %   segment.
    %
    %   DELTAPLOT(___,Name,Value) specifies additional options for
    %   the plot using one or more name-value pair arguments.
    %   Specify the options after all other input arguments.
    %
    %   DELTAPLOT(Parent,___) plots into Parent instead of GCF.
    %
    %   D = DELTAPLOT(___) returns the deltaplot object. Use D to
    %   modify properties of the chart after creating it.
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        XData (:,2) {mustBeNumeric} = [NaN NaN]
        YData (:,2) = []
        ItemLabels (:,1) string = []
        EndPointLabels (2,1) = ["Beginning"; "Ending"]
        
        Title (:,1) string = ""
        XLabel (:,1) string = ""
        YLabel (:,1) string = ""
        
        ItemLabelsVisible (1,1) matlab.lang.OnOffSwitchState = 'on'
        GridVisible (1,1) matlab.lang.OnOffSwitchState = 'on'
        
        ColorOrder = get(groot,'DefaultAxesColorOrder') % property validated in the setter
        Marker (1,:) char {mustBeMember(Marker,{'o','*','+','p','h','^','v','>','<','x','+','s','d','.','none'})} = 'o'
        LineWidth (1,1) {mustBeNumeric, mustBePositive} = 2
    end
    
    properties(Dependent)
        XLimits (1,2) double {mustBeLimits} = [0 1]
        YLimits (1,2) double {mustBeLimits} = [0 1]
    end
    
    properties (Access = protected)
        % Used for saving to .fig files
        ChartState = []
    end
    
    properties(Access = private,Transient,NonCopyable)
        PatchHandle (1,:) matlab.graphics.primitive.Patch
        PatchYData (:,1) double
        PatchXData (:,1) double
        PatchFaceVertexCData (:,1) double
        TextHandles (1,:) matlab.graphics.primitive.Text
        
        % Colormap to create color gradient between start and end points.
        Colormap (:,3) double
        
        % Invisible Stem objects to populate legend.
        Stem1  (1,:) matlab.graphics.chart.primitive.Stem
        Stem2  (1,:) matlab.graphics.chart.primitive.Stem
        
        % Property that stores which style of chart to draw:
        %    "ItemLabels" means y-values have not been provided. Horizontal
        %         line segments will draw using ItemLabels for the y-axis values.
        %    "YData" means numeric y-values have been provided and line
        %         segments will draw from (x1,y1) to (x2,y2). ItemLabels
        %         will be used to label the start point of each segment.
        YDataSource (1,1) string {mustBeMember(YDataSource, ["YData", "ItemLabels"])} = "YData"
        
        % Internal management of YLimits because custom ylimits are chosen
        % when YDataSource == ItemLabels.
        YLimits_I (1,2) double = [-Inf Inf]
        YLimitsMode (1,1) string {mustBeMember(YLimitsMode, ["auto", "manual"])} = "auto"
    end
    
    methods
        %% Constructor
        function obj = deltaplot(varargin)
            
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);
            
            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % deltaplot(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end
            
            % Check for optional positional arguments.
            if ~isempty(args) && numel(args) >= 2
                if isnumeric(args{1}) && isnumeric(args{2})
                    
                    n1 = args{1}(:); % assure column vector
                    n2 = args{2}(:);
                    
                    % check that data sizes match
                    if all(size(n1) == size(n2))
                        if numel(args) >=4 && isnumeric(args{3}) && isnumeric(args{4})
                            % deltaplot(x1, y1, x2, y2, ...)
                            n3 = args{3}(:); % assure column vector
                            n4 = args{4}(:);
                            
                            % check that additional data sizes match
                            if all(size(n3) == size(n4))
                                leadingArgs = [leadingArgs {'XData', [n1 n3], 'YData', [n2 n4]}];
                                args = args(5:end);
                            else
                                error('Size of all coordinate vectors must be the same.');
                            end
                        else
                            % deltaplot(x1, x2, ...)
                            leadingArgs = [leadingArgs {'XData', [n1 n2]}];
                            args = args(3:end);
                        end
                    else
                        error('Size of all coordinate vectors must be the same.');
                    end
                    if ~isempty(args) && (mod(numel(args),2) == 1)
                        if isstring(args{1}) || iscategorical(args{1}) || iscellstr(args{1})
                            % deltaplot(..., names)
                            
                            labels = args{1}(:); % force column vector
                            
                            % check that the number of item labels matches
                            % the number of line segments
                            if all(size(n1) == size(labels))
                                leadingArgs = [leadingArgs {'ItemLabels', labels}];
                                args = args(2:end);
                            else
                                error('Number of item labels must match the number of elements in the coordinate vectors.');
                            end
                        else
                            error('Wrong input arguments');
                        end
                    else
                        labels = string((1:numel(n1))');
                        leadingArgs = [leadingArgs {'ItemLabels', labels}];
                    end
                end
            end
            
            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];
            
            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end
        
        %% Property Setters and Getters
        function set.ItemLabels(obj,val)
            if isempty(obj.YData)
                obj.YDataSource = "ItemLabels";
            end
            obj.ItemLabels = val;
        end
        
        function set.YData(obj,val)
            if isempty(val)
                obj.YDataSource = "ItemLabels";
            else
                obj.YDataSource = "YData";
            end
            obj.YData = val;
        end
        
        function set.XLimits(obj,val)
            obj.getAxes.XLim = val;
        end
        
        function val = get.XLimits(obj)
            val = obj.getAxes.XLim;
        end
        
        function set.YLimits(obj,val)
            obj.YLimitsMode = "manual";
            obj.YLimits_I = val;
        end
        
        function val = get.YLimits(obj)
            val = obj.getAxes.YLim;
        end
        
        function set.ColorOrder(obj,val)
            try
                colors = validatecolor(val,'multiple');
            catch e
                warning(e.message)
                return;
            end
            if height(colors)>2
                warning('Only the first two colors provided to ColorOrder will be used.')
            end
            
            % Choose the first two colors for the color gradient.
            color1 = colors(1,:);
            if size(colors,1) >= 2
                color2 = colors(2,:);
            else
                % If only one color available, there will be no color
                % gradient
                color2 = colors(1,:);
            end
            
            % compute a colormap to for the gradient between the two colors
            cmaplen = 255;
            cmap = [linspace(color1(1),color2(1),cmaplen)',...
                linspace(color1(2),color2(2),cmaplen)',...
                linspace(color1(3),color2(3),cmaplen)'];
            
            obj.Colormap = cmap;
            obj.ColorOrder = colors;
        end
        
        %% Convenience Function Support
        function title(obj,txt)
            %                 if isnumeric(txt)
            %                     txt=num2str(txt);
            %                 end
            obj.Title = txt;
        end
        
        function varargout = ylim(obj, varargin)
            % Call the standard ylim method on the axes
            ax = obj.getAxes();
            [varargout{1:nargout}] = ylim(ax, varargin{:});
            obj.YLimits = ax.YLim;
        end
        
        function varargout = xlim(obj, varargin)
            % Call the standard xlim method on the axes
            ax = obj.getAxes();
            [varargout{1:nargout}] = xlim(ax, varargin{:});
        end
        
        %% ChartState (for save/load)
        function data = get.ChartState(obj)
            % This method gets called when a .fig file is saved
            isLoadedStateAvailable = ~isempty(obj.ChartState);
            
            if isLoadedStateAvailable
                data = obj.ChartState;
            else
                data = struct;
                ax = getAxes(obj);
                
                % Get axis limits only if mode is manual.
                if strcmp(ax.XLimMode,'manual')
                    data.XLimits = ax.XLim;
                end
                if strcmp(ax.YLimMode,'manual')
                    data.YLimits = ax.YLim;
                end
                
                data.YLimitsMode = obj.YLimitsMode;
                data.YDataSource = obj.YDataSource;
                data.ColorOrder = obj.ColorOrder;
            end
        end
        
        function loadstate(obj)
            % This method is called at the end of setup and is used to
            % handle loading of .fig files.
            
            data=obj.ChartState;
            ax = getAxes(obj);
            
            % Look for values saved in the fig file.
            if isfield(data, 'XLimits')
                ax.XLim=data.XLimits;
            end
            if isfield(data, 'YLimits')
                ax.YLim = data.YLimits;
                obj.YLimits_I = data.YLimits;
            end
            
            obj.YLimitsMode = data.YLimitsMode;
            obj.YDataSource = data.YDataSource;
            obj.ColorOrder = data.ColorOrder;
        end
        
    end  % end public methods
    
    methods (Access = protected)
        
        function setup(obj)
            % Create the axes
            ax = getAxes(obj);
            box(ax,'on');

            % Turn legend on and place it outside to the right
            obj.LegendVisible = 'on';
            ax.Legend.Layout.Tile = 'east';

            % Create patch and indicate it should not appear in legend
            obj.PatchHandle = patch(ax, 'XData',NaN,'YData',NaN, 'FaceVertexCData',NaN,...
                'EdgeColor','interp','MarkerFaceColor','flat');
            obj.PatchHandle.Annotation.LegendInformation.IconDisplayStyle='off';
            
            % trigger colororder setter to compute colormap
            colors = get(groot,'DefaultAxesColorOrder');
            obj.ColorOrder = colors(1:2,:);
            
            % Set axes toolbar buttons (remove brush):
            axtoolbar(ax, {'export' 'datacursor' 'pan' 'zoomin','zoomout','restoreview'});
            
            % Inivisble stem objects for legend only
            hold(ax,'on')
            obj.Stem1 = stem(ax,NaN, NaN, "filled");
            obj.Stem2 = stem(ax,NaN, NaN, "filled");
            
            ax.Legend.Layout.Tile = 'east';
            
            % Call the load method in case of loading from a fig file
            loadstate(obj);
        end
        
        function update(obj)
            % Validate data sizes match
            validData = validateDataSizes(obj);
            
            if ~validData
                % If data sizes do not match, make the chart look empty.
                set(obj.getAxes.Children, 'Visible', 'off');
            
            else
                % If data sizes match, proceed with a normal update.
                set(obj.getAxes.Children, 'Visible', 'on');
                
                % Compute Patch Vertices
                computePatchVertices(obj);
                
                % Update Patch Data
                set(obj.PatchHandle, "XData", obj.PatchXData, ...
                    "YData", obj.PatchYData, ...
                    "FaceVertexCData", obj.PatchFaceVertexCData);
                
                % Update Marker and Line Width
                set(obj.PatchHandle, "Marker", obj.Marker, "LineWidth", obj.LineWidth);
                set([obj.Stem1 obj.Stem2],"Marker", obj.Marker, "LineWidth", obj.LineWidth);
                
                % Update legend display names
                obj.Stem1.DisplayName = obj.EndPointLabels(1);
                obj.Stem2.DisplayName = obj.EndPointLabels(2);
                
                % Get y-ticks looking good
                ax = obj.getAxes;
                if obj.YDataSource == "ItemLabels"
                    % manually set ticks to match string or categorical labels
                    ax.YTick = 1:numel(obj.ItemLabels);
                    ax.YTickLabel = string(obj.ItemLabels);
                elseif obj.YDataSource == "YData"
                    % reset ticks to auto mode for the numeric case
                    ax.YTickMode = 'auto';
                    ax.YTickLabelMode = 'auto';
                end
                
                if obj.YLimitsMode == "manual"
                    % If user has requested specific YLimits, honor those.
                    ax.YLim = obj.YLimits_I;
                    
                elseif obj.YDataSource == "YData" && strcmp(ax.YLimMode,'manual')
                    % In the numeric YData case, check if the Axes y-limits have
                    % gotten into manual mode some other way (pan, zoom.) Store
                    % those as we do other manual YLimits.
                    obj.YLimitsMode = "manual";
                    obj.YLimits_I = ax.YLim;
                    
                    % Otherwise, choose automatic limits for the user.
                elseif obj.YDataSource == "ItemLabels"
                    % When the YData is drawn from ItemLabels, choose automatic
                    % limits that will center the y-ticks on the ruler.
                    ax.YLim = [min(ax.YTick) - 0.5, max(ax.YTick) + 0.5];
                else
                    % Otherwise just rely on the automatic limit picking in
                    % Axes.
                    ax.YLimMode = 'auto';
                end
                
                % Set Colors
                ax.Colormap = obj.Colormap; % used by the Patch (color gradient)
                ax.ColorOrder = obj.ColorOrder; % used by the Stem objects (legend)
                
                % Set Grid
                if obj.GridVisible
                    if obj.YDataSource == "ItemLabels"
                        % x grid only for the categorical/string case
                        ax.XGrid = 'on';
                        ax.YGrid = 'off';
                    else
                        grid(ax,'on');
                    end
                else
                    grid(ax,'off');
                end
                
                % Set title & labels
                title(ax, obj.Title);
                xlabel(getAxes(obj), obj.XLabel);
                ylabel(getAxes(obj), obj.YLabel);
                
                % Draw ItemLabels
                drawLabels(obj);
            end
        end
        
        function propgrp = getPropertyGroups(obj)
            if ~isscalar(obj)
                propgrp = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            else
                propList = struct('XData',obj.XData);
                if obj.YDataSource == "YData"
                    propList.YData = obj.YData;
                    propList.ItemLabels = obj.ItemLabels;
                    propList.ItemLabelsVisible = obj.ItemLabelsVisible;
                elseif obj.YDataSource == "ItemLabels"
                    propList.ItemLabels = obj.ItemLabels;
                end
                propList.EndPointLabels = obj.EndPointLabels';
                propList.GridVisible = obj.GridVisible;
                propList.Marker = obj.Marker;
                propList.LineWidth = obj.LineWidth;
                propList.ColorOrder = obj.ColorOrder;
                
                propgrp = matlab.mixin.util.PropertyGroup(propList);
            end
        end
    end
    % end protected methods
    
    methods (Access = private)
        function allgood = validateDataSizes(obj)
            allgood = true;
            if obj.YDataSource == "YData" && height(obj.YData) ~= height(obj.XData)
                warning('XData and YData must be the same size.')
                allgood = false;
            elseif height(obj.ItemLabels) ~= height(obj.XData)
                warning('XData and ItemLabels must be the same height.')
                allgood = false;
            end
        end
        function computePatchVertices(obj)
            % Remove any NaN's from the data
            nan_inds = any(isnan(obj.XData),2);
            
            % Compute Patch YData
            if obj.YDataSource == "YData"
                nan_inds = nan_inds | any(isnan(obj.YData),2);
                yd = obj.YData(~nan_inds,:);
            elseif obj.YDataSource == "ItemLabels"
                yd = 1:numel(obj.ItemLabels);
                yd = yd(~nan_inds);
                yd = [yd(:) yd(:)];
            end
            yd = [yd nan(height(yd),1)];
            obj.PatchYData = reshape(yd',numel(yd),1);
            
            % Compute Patch XData
            xd = obj.XData(~nan_inds,:);
            xd = [xd nan(height(xd),1)];
            obj.PatchXData = reshape(xd',numel(xd),1);
            
            obj.PatchFaceVertexCData = repmat([1;2;2],numel(yd)/3,1);
        end
        
        function drawLabels(obj)
            delete(obj.TextHandles);
            
            % Only show ItemLabels in the X/Y case (YDataSource='YData')
            if obj.YDataSource == "YData" && ~isempty(obj.ItemLabels) && obj.ItemLabelsVisible
                
                yspan = diff(obj.getAxes.YLim);
                
                if ~isfinite(yspan)% Ylimits can be -Inf Inf or similar
                    yspan =  max(obj.getAxes.YTick) - min(obj.getAxes.YTick);
                end
                
                % determine positions for text objects
                xlocs = nan(height(obj.XData),1);
                ylocs = nan(height(obj.XData),1);
                
                finiteInds = find(all(isfinite(obj.XData) & isfinite(obj.YData),2));
                
                for i = finiteInds'
                    xlocs(i) = obj.XData(i,1);
                    ylocs(i) = obj.YData(i,1);
                    ylocs(i) = ylocs(i) - yspan*0.01; % adjust label down by 1% of axes height
                end
                
                % create text objects
                obj.TextHandles = text(obj.getAxes,xlocs,ylocs,obj.ItemLabels,...
                    'HorizontalAlignment','left','VerticalAlignment','top');
            end
        end
    end
    % end private methods
end

% validator for the XLimits and YLimits properties
function mustBeLimits(a)
if numel(a) ~= 2 || a(2) <= a(1)
    throwAsCaller(MException('densityScatterChart:InvalidLimits', 'Specify limits as two increasing values.'))
end
end