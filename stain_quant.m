function stain_quant(exp_dir,varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setup variables and parse command line
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i_p = inputParser;

i_p.addRequired('exp_dir',@(x)exist(x,'dir') == 7);

i_p.addParameter('edge_search_str','*Cy5.TIF',@(x)ischar(x));
i_p.addParameter('second_search_str','*FWTR.TIF',@(x)ischar(x));

i_p.parse(exp_dir,varargin{:});

edge_files = dir(fullfile(exp_dir,i_p.Results.edge_search_str));

secondary_files = dir(fullfile(exp_dir,i_p.Results.second_search_str));

load('config.mat');

%get some scripts from my matlab methods
addpath(genpath(misc_image_processing_dir));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

intensity_measurements = [];

for i = 1:length(secondary_files)
    this_secondary_file = fullfile(exp_dir,secondary_files(i).name);
    this_edge_file = fullfile(exp_dir,edge_files(i).name);
    
    secondary = double(imread(this_secondary_file));
    edge_image = double(imread(this_edge_file));
    ratio_image = edge_image./secondary;
    
    secondary_norm = normalize_image(secondary);
    edge_image_norm = normalize_image(edge_image);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Edge Finding
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    edge_hp = apply_high_pass_filter(edge_image,10);
    
    edge_binary = edge_hp > 0.25*std(edge_hp(:));
    edge_binary = bwpropopen(edge_binary,'Area',400,'connectivity',4);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Vesicle Finding
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    secondary_hp = apply_high_pass_filter(secondary,10);
    
    vesicle_binary = secondary_hp > 0.5*std(secondary_hp(:));
    
    vesicle_binary = vesicle_binary & not(edge_binary);
    
    vesicle_binary = bwpropopen(vesicle_binary,'Area',10,'connectivity',4);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Visualization
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    highlight_set = int16(edge_binary);
    highlight_set(vesicle_binary) = 2;
    
    %suggestion from Colorbrewer
    highlight_cmap = [[175,141,195]/255;[127,191,123]/255];
    
    edge_image_highlight = create_highlighted_image(edge_image_norm,highlight_set,...
        'mix_percent',0.5,'color_map',highlight_cmap);
    secondary_image_highlight = create_highlighted_image(secondary_norm,highlight_set,...
        'mix_percent',0.5,'color_map',highlight_cmap);
        
    %%Visualization Output
    [path,edge_name,~] = fileparts(this_edge_file);
    [~,sec_name,~] = fileparts(this_secondary_file);
    
    imwrite(edge_image_highlight,fullfile(path,[edge_name,'_edge.png']));
    imwrite(secondary_image_highlight,fullfile(path,[sec_name,'_secondary_edge.png']));

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Data Collection
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    intensity_measurements = [intensity_measurements; ...
        mean(edge_image(edge_binary)),mean(secondary(edge_binary)),...
        mean(ratio_image(edge_binary)),mean(edge_image(vesicle_binary)),...
        mean(secondary(vesicle_binary)),mean(ratio_image(vesicle_binary))]; %#ok<AGROW>
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Data Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
headers = {'Edge in Edge','Edge in 2nd','Edge in Ratio','Vesicle in Edge',...
    'Vesicle in 2nd','Vesicle in Ratio'};
csvwrite_with_headers(fullfile(exp_dir,'quantification.csv'),intensity_measurements,...
    headers);
