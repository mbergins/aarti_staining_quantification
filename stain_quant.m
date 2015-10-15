function stain_quant(exp_dir,varargin)
%Quantify Ecad Stains
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setup variables and parse command line
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i_p = inputParser;

i_p.addRequired('exp_dir',@(x)exist(x,'dir') == 7);

i_p.addParameter('edge_search_str','*Cy5.TIF',@(x)ischar(x));
i_p.addParameter('second_search_str','*FWTR.TIF',@(x)ischar(x));

i_p.addParameter('background_threshold',300,@(x)isnumeric(x));
i_p.addParameter('background_min_size',250000,@(x)isnumeric(x));

i_p.addParameter('band_size',100,@(x)isnumeric(x));

i_p.parse(exp_dir,varargin{:});

edge_files = dir(fullfile(exp_dir,i_p.Results.edge_search_str));

secondary_files = dir(fullfile(exp_dir,i_p.Results.second_search_str));

load('config.mat');

%get some scripts from my matlab methods
addpath(genpath(misc_image_processing_dir));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

measurements = [];

%this should be big enough to hold all the results from banding the
%intensity values
ratio_bands = zeros(length(secondary_files),10000);

max_band_count = 0;

for file_num = 1:length(secondary_files)
    this_secondary_file = fullfile(exp_dir,secondary_files(file_num).name);
    this_edge_file = fullfile(exp_dir,edge_files(file_num).name);
    
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
    % Background Finding
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    background_region = edge_image < i_p.Results.background_threshold;
    
    background_region = imfill(background_region,'holes');
    background_region = bwpropopen(background_region,...
        'Area',i_p.Results.background_min_size,'connectivity',4);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Visualization
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    highlight_set = int16(edge_binary);
    highlight_set(vesicle_binary) = 2;
    highlight_set(background_region) = 3;
    
    %suggestion from Colorbrewer
    highlight_cmap = [[175,141,195]/255;[127,191,123]/255;[5,113,176]/255];
    
    edge_image_highlight = create_highlighted_image(edge_image_norm,highlight_set,...
        'mix_percent',0.5,'color_map',highlight_cmap);
    secondary_image_highlight = create_highlighted_image(secondary_norm,highlight_set,...
        'mix_percent',0.5,'color_map',highlight_cmap);
    
    %%Visualization Output
    [path,edge_name,~] = fileparts(this_edge_file);
    [~,sec_name,~] = fileparts(this_secondary_file);
    
    imwrite(edge_image_highlight,fullfile(path,[edge_name,'_highlight.png']));
    imwrite(secondary_image_highlight,fullfile(path,[sec_name,'_highlight.png']));
    
    imwrite(ratio_image,fullfile(path,[sec_name,'_ratio.png']));
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Data Collection
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    measurements = [measurements; ...
        mean(edge_image(edge_binary)),mean(secondary(edge_binary)),...
        mean(ratio_image(edge_binary)),mean(edge_image(vesicle_binary)),...
        mean(secondary(vesicle_binary)),mean(ratio_image(vesicle_binary)),...
        sum(sum(edge_binary))/sum(sum(~background_region)),...
        sum(sum(vesicle_binary))/sum(sum(~background_region))]; %#ok<AGROW>
        
    %Ratio Image Banding
    % Check to make sure there is a background region found, otherwise,
    % infinite loop
    if (any(background_region(:)))
        background_dist = bwdist(background_region);
        
        band_limits = [0, i_p.Results.band_size];
        band_counter = 1;
        while (band_limits(1) <= max(background_dist(:)))
            this_band = background_dist > band_limits(1) & background_dist <= band_limits(2);
            ratio_bands(file_num,band_counter) = mean(ratio_image(this_band));
            
            band_counter = band_counter + 1;
            band_limits = band_limits + i_p.Results.band_size;
        end
        
        if (band_counter > max_band_count), max_band_count = band_counter; end
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Data Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
headers = {'Edge in Edge','Edge in 2nd','Edge in Ratio','Vesicle in Edge',...
    'Vesicle in 2nd','Vesicle in Ratio','Edge Area Percent','Vesicle Area Percent'};
csvwrite_with_headers(fullfile(exp_dir,'quantification.csv'),measurements,...
    headers);

ratio_bands = ratio_bands(:,1:max_band_count);
ratio_headers = cell(0);
band_limits = [0, i_p.Results.band_size];
for i = 1:size(ratio_bands,2)
    ratio_headers{i} = sprintf('%d - %d',band_limits(1),band_limits(2));
    band_limits = band_limits + i_p.Results.band_size;
end

csvwrite_with_headers(fullfile(exp_dir,'ratio_band_means.csv'),ratio_bands,...
    ratio_headers);