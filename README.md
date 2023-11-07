# Boney
This is the Boney toolbox, an extension to [SPM12](http://www.fil.ion.ucl.ac.uk/spm/software/spm12/) and its [CAT12](http://www.neuro.uni-jena.de/cat) toolbox, supporting the extraction of measurements related to the bone and head structure. It is developed by *Polona Kalc* and *Robert Dahnke* and is a free but copyright software, distributed under the terms of the <em>[GNU General Public License](http://www.gnu.org/licenses/gpl-2.0.html)</em> as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

If you find any bugs, please report them to <polona.kalc@med.uni-jena.de> or <robert.dahnke@uni-jena.de>.


## Introduction 
As Ingmar Bergman posited in The Seventh Seal: *'A skull is more interesting than a naked woman.'* Yet the neuroimaging community has continued to strip the skull and discard the relevant information hidden in the layers of the head tissues. 
The increasing interest in the bone-brain crosstalk suggests the implication of bone metabolism in mood, cognition, energy homeostasis, etc. ([Khrimian et al. 2017](10.1084/jem.20171320); [Nakamura, Imaoka, and Takeda 2021](https://doi.org/10.1080/00207454.2020.1770247) ; [Obri et al. 2018](10.1038/nrendo.2017.181); [Rousseaud et al. 2016](https://doi.org/10.1515/hmbci-2016-0030)). Furthermore, low bone mineral density (BMD)/osteoporosis has been associated to an increased risk of Alzheimer's disease ([Kostev, Hadji, and Jacob 2018](https://doi.org/10.3233/JAD-180569); [Zhang et al. 2022](https://doi.org/10.1016/j.jamda.2022.07.012); [Xiao et al. 2023](10.1212/WNL.0000000000207220)).
However, the bone mineral density measures are typically not available in open-access brain-imaging databases, such as IXI, ADNI, AIBL, OASIS, etc. We therefore decided to extract a proxy measure for head BMD from the skull. 


## Quick method
To extract bone parameters from MRI data, we use a refined SPM tissue segmentation procedure and derive different cranial intensity and thickness measures that can be used to approximate the head BMD measure.
An estimation of the head's skin-fold (subcutaneous fat thickness) is also available and can be used as an additional information to the typically available BMI measure.


## Quick start
Install Matlab/Octave, [SPM12](http://www.fil.ion.ucl.ac.uk/spm/software/spm12/) and its [CAT12](http://www.neuro.uni-jena.de/cat) toolbox.
Download the zip-file and unpack it into your SPM12 toolbox directory. 

Run SPM and open the toolbox:

<code>spm fmri; spm_boney;</code>

Open the bone processing batch: 

![Image of the Boney menu and the bone-processing-batch](images/Boney_toolbox.png "Shown is the bone-processing batch that can be used to extract processed bone measures into a CSV table.")

and select the structural images that should be processed. Adapt relevant parameters (see paragraph Parameters and SPM batch help) and start the processing. Voilà! 

After the processing has finished, you can use the XML2CSV batch to extract the estimated (bone) values for further analyses.



## Parameters
You can select different predefined SPM and CAT segmentation routines with various predefined settings. 
SPM's routine is faster but may fail in some cases, often because of the inital affine registration problems. 

In addition, you can select between different advanced processing routines for the bone measures (e.g., *SPMmat*, *volume*, *surface*).  
SPMmat focuses on the tissue values estimated within the unified segmenation process and is therefore pretty fast (+5 seconds). 
The *volume* option further refines the bone tissue segment (high bone marrow intensities within the diploë were often misclassified as head tissue) and estimates (regional) intensity and thickness of the bone class (+50 seconds). 
The *surface* pipeline creates a central bone surface that is used to extract intensity- and thickness values for (i) the bone cortex by mapping the *minimum* intensity along the surface normals, and (ii) the bone marrow by using the weighted average intensity (+10 seconds).   
(We would advise the use of the refined measure, which is robust to the exclusion of the parts within the diploë.)


Furthermore, you can specify which output files to write, e.g., the short bone-report (as a JPG), or the processed NIFTI volumes or GIFTI surfaces that are also shown in the bone-report.

![Image of the bone atlas and mask](images/KADA_regions_mask.png "Shown is the bone atlas and the bone mask.")


## Results
For each subject Boney writes a report file and a mat file that include all processed values.  While processing, the major measure of the just processed subject are promted on the command line.  The parameters are group by processing aspects listed in table #.  The T* paramter are derived from the SPM/CAT preprocessing and code major information about the given input MRI.  The following mean thickness (th) or intensity parameters were created volume- or surface-base (v/s) in the masked occiptial-region of the head (H), bone (B) cortex (cor), marrow (mar) or full structure (see table).  Intensity-based measures were normalized for CSF intensity but depend strongly on the protocol.

| nr | parameters | content |
| -: | ---------- | --------| 
|  1 | Tw         | MRI image weighting (T1w, T2w, PDw, ...) |
|  2 | Tbg        | Backgound intensity (e.g. low in MPRage, high in many MP2Rage, MT, R1 protocols |
|  3 | Tfat       | Use of fat suppression protocol that reduces the bone (marrow) intensity that is affected by fat | 
|  4 | Tres       | RMS resolution quality measure, i.e. weighted-average resolution in mm (lower=better) | 
|  5 | Tcnr       | Contrast-to-noise ratio to roughly quantify image quality and presents of motion artifacts (lower=better)|
|  6 | v/sBmar    | Volume/surface-based bone marrow measure |
|  7 | v/sBcor    | Volume/surface-based bone cortex measure (~bone mineral density) | 
|  8 | v/sBth     | Volume/surface-based bone thickness (marrow and cortex) |
|  9 | v/sHth     | Volume/surface-based head thickness (fat muscles) |
| 10 | v/sHmed    | Volume/surface-based head intensity (median of all voxel-values, protocol dependent!) |
| 11 | Tbcor      | SPM-based bone cortex intensity - the minimum of the typically 3 Gaussians of the unified segmentation (basic measure only for debugging/tests/comparison) |
| 12 | Tbmar      | SPM-based bone cortex intensity - the maximum of the typically 3 Gaussians of the unified segmentation (basic measure only for debugging/tests/comparison) |
| 13 | Tbdns      | SPM-based bone density - volume-ratio between SPM minimum and median Gaussian (expert, only for comparison) |
| 14 | Tmed(c)    | Volume-based (classic) median bone intensity of the corrected bone (expert, only for comparison) |

In addition, a csv-table of the most relevant measures (including tissue volumes) for all subjects is created at the end of the processing. The csv-export batch can be used to create independent table of previously processed data by selecting the XML-reports of interest. 


![Bonereport](images/boney_bonereport2_OASIS131.jpg "Shown is the bone report with ... Oups, this report need an update for the histogram...")
Figure: Bonereport with (1) Table 1 with the tissue intensities and absolute/relative volumes, (2) Table 2 with specific bone and head values (see abbreviations for details, (3) a histogram with the major values, (4) two volumes (i) the orignal image with bone and fat overlay and (ii) the normalized bone intensities with GM, WM and head (HD) segment for orientation, and (5) two surface sets (i) with bone thickness (and atlas boundaries) and (ii) the bone marrow intensity.  
Abbreviations: 
Table 1: GM=grey matter, WM=white matter, CSF=cerebrospinalfluid, BG=background, TPM=tissue probability map, Norm.Med.Int.=normalized median intensity.
Table 2: Tw=image weighting, Tres=root mean square resolution rating, Tbg=background type, Tfat=heat fat suppression type, Tbone=bone fat intensity, sBcor=surface-base bone-cortex intensity, sBmar=surface-based bone-marrow intensity, sBth=surface-based bone thickness, sHth=surface-based head thickness.


## Validation
*RD: Show only the main measures for BMD and FAT linked with the processing routines*


The figure shows the results for the selected bone measures estimated on a UKB subsample created by the evaluation scripts.
The most relevant regional bone measures are (i) the occipital surface-based bone cortex estimate *sROI_bonecortex3*, (ii) the occipital volume-based bone marrow estimate *vROI_bonemarrow3*, and the *bone mineral density estimate* (BMD) that show a high correlation to the UKB BMD measures.

In addition, the estimated head fat measure is supported by high correlations with visceral adipose tissue (VAT), abdominal subcutaneous adipose tissue (ASAT), body fat percentage, BMI, and waist measurements of the UKB. 

![Basic evaluation on UKB data](images/mt12_BoneyS_site8_n360.png "Shown are the result of selected bone measures on a small subsample of the UKB with 360 subjects.")

![MRI bone measure](images/mt12_BoneyS_site8_n360_vROI_BMDH.png "MRI bone measure on a small subsample of the UKB with 360 subjects.")

![MRI fat measure](images/mt12_BoneyS_site8_n360_vhdt1.png "MRI fat measure on a small subsample of the UKB with 360 subjects.")


## References
You can find out more about the bone and skin-fold thickness measures in the paper ...


![](images/AdobeStock_375705917_Preview.jpg "Just a bone pile - Did you know that ...")
