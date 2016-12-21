# Edge and Vesicle Staining Quantification

This MATLAB script segments the edges and vesicles from two sets of images and then calculates the properties of these structures. It was originally developed for images of E-cadherin staining paired with a secondary vesicular stain, although any set of images with an edge and vesicle label should work. The image with a prominent edge stain is segmented using a high-pass filter and a threshold based on the standard deviation of the filtered image. A similar technique is used to segment the vesicles from the secondary images, with some additional filters on the size of the vesicles. The code also attempts to find a background region of the image that does contain any cells. After finding these structures, a set of visualizations are produced which show where the edges and vesicles were identified. Finally, some properties of the edges and vesicles are quantified.

##Using the Code

The primary script is "stain_quant.m" and it makes a few assumptions about how you have your data organized. The only required input is a directory, which is expected to contain a set of images that need to be processed. The other options are not required, but may need to be customized to match your imaging conditions and file naming structure.

* exp_dir (required): A directory that contains your edge and vesicular staining images
* edge_search_str (optional): A string used to search exp_dir for your edge images
* secondary_search_str (optional): A string used to search exp_dir for your vesicular images
* background_threshold (optional, Arbitrary Units): A number used as a threshold for finding the background from your edge images
* background_min_size (optional, pixels): A number used to filter out any background regions smaller than this value
* vesicle_thresh (optional): A number used to set how stringently to filter the vesicular image
* band_size (optional): A number used to set how thick the bands should be for analyzing the properties at different distances from the edge of the background region

###Expected Outputs

The code will produce two types of output: visualizations that indicate where the edges and vesicles are found and quantifications of the stains. The visualization files are all named based on the source file names. The edges are colored with purple, the vesicles with green and the background with blue.

The staining quantifications are output in a CSV file named "quantification.csv". That file contains a set of measurements for each set of edge/vesicle images which includes:

* Edge in Edge: The average intensity of the edge pixels in the edge image
* Edge in 2nd: The average intensity of the edge pixels in the vesicle image
* Edge in Ratio: The average intensity of the edge pixels in the ratio image
* Vesicle in Edge: The average intensity of the vesicle pixels in the edge image
* Vesicle in 2nd: The average intensity of the vesicle pixels in the vesicle image
* Vesicle in Ratio: The average intensity of the vesicle pixels in the ratio image
* Edge Area Percent: The percentage of the area taken up by the edge pixels in the non-background region
* Vesicle Area Percent: The percentage of the area taken up by the vesicle pixels in the non-background region
* Vesicle Threshold: The threshold used to find the vesicles

The ratio images are calculated as edge/vesicle in case these values are of interest.

There is another quantification output that measures the mean intensity in the ratio and vesicle images at various distances from the background edge. The size of the band can be adjusted with the 'band_size' option.

###Caveats and Pitfalls

The output files are produced for each folder analyzed, so I would organize each condition into seperate folders (e.g. wild-type and knockdown in seperate folders). The visualizations for each image shouls also be inspected to ensure that the methods are properly finding the edge and vesicle regions.
