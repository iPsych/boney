function varagout = boney_xml2csv(job)
%boney_xml2csv(job). Wrapper to call cat_io_xml2csv for boney structure. 
% See cat_io_xml2csv.
%
%  varagout = boney_xml2csv(job)
% 
%  
% _________________________________________________________________________
%
% Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% _________________________________________________________________________
% $Id$

  %job = cat_io_checkin(job,def);

  % define general boney fields that should be avoided even for
  % developers such as help or log entries
  job.avoidfields = [ job.avoidfields; 
    {'help'; 'catlog'; 'error'; 'hardware'; 'P.orgpp';'P.orgff'; }];
  job.dimlim = 10;


  % maybe we need some predefined structures for better named regions etc.  
  job.fieldnames = { ...
    ... filename
    'P.org';
    ... opts
    'opts.pmethod'; 'opts.bmethod';
    'date'; 
    ... SPM image parameter
    'tis.weightingn'; 'tis.highBGn';    'tis.headFatTypen'; 'tis.boneIntTypen';         % basic information about the image
    'tis.bonecortex'; 'tis.bonemarrow'; 'tis.bonedensity';  'tis.bone'; 'tis.head';   
    ... volume measurements
    'tismri.TIV'; 
    'tismri.volr(01)'; 'tismri.volr(02)'; 'tismri.volr(03)'; 'tismri.volr(04)'; 'tismri.volr(05)'; % relative tissue volumes 
    'tismri.volmus'; 'tismri.volfat'; 'tismri.volfatr'; 'tismri.volmusr';
    ... voxel-based measurements (3-occ,4-rpar,5-lpar)
    'vROI.bonecortex(03)';    'vROI.bonemarrow(04)';    'vROI.bonemarrow(05)'; 
    'vROI.bonethickness(03)'; 'vROI.bonethickness(04)'; 'vROI.bonethickness(05)';
    'vROI.headthickness(03)'; 'vROI.headthickness(04)'; 'vROI.headthickness(05)';
    ... surface-based measurements
    'sROI.bonecortex(03)';    'sROI.bonemarrow(04)';    'sROI.bonecortex(05)'; 
    'sROI.bonethickness(03)'; 'sROI.bonethickness(04)'; 'sROI.bonethickness(05)';
    'sROI.headthickness(03)'; 'sROI.headthickness(04)'; 'sROI.headthickness(05)';
    };

 
  % add extra expert/developer fields
  switch job.report
    case {'boney_details','boney_expert','boney_developer'}
      job.fieldnames = [job.fieldnames; {
        'tismri.vol(01)';  'tismri.vol(02)';  'tismri.vol(03)';  'tismri.vol(04)';  'tismri.vol(05)';  % absolute tissue volumes
        'vROI.bonemarrow';'vROI.bonecortex';'vROI.bonethickness';'vROI.headthickness';'vROI.head';
        'sROI.bonecortex';'sROI.bonecortex';'sROI.bonethickness';'sROI.headthickness';'sROI.head';
        } ]; 
    case {'all'}
      xml = cat_io_xml(job.files(1));
      job.fieldnames = unique( [ job.fieldnames; getFN(xml)] ); 
  end
    
  switch job.report
    case {'boney_expert','boney_developer'}
      job.fieldnames = [job.fieldnames; {
        'opts.bias';'opts.ctpm'; 'opts.refine'; 'opts.reduce';
        } ]; 
  end
  switch job.report
    case {'boney_developer'}
      job.fieldnames = [job.fieldnames; {
        'tis.clsQC';
        } ]; 
  end

  % replace DATE by current data
  job.fname = strrep(job.fname,'DATE',datestr(clock,'YYYYmmDD-HHMMSS'));
  job.fname = strrep(job.fname,'REPORT',job.report);

  varagout{1} = cat_io_xml2csv_boney(job);

end
% RD20230929: We just keep the updated cat_io_xml2csv here as the official CAT 
%             release still include the old version.
function varargout = cat_io_xml2csv_boney(job)
%cat_io_xml2csv_boney. Save all variables of a set of XML-files in one csv-file. 
%
%  table = cat_io_xml2csv_boney        .. GUI version
%  table = cat_io_xml2csv_boney(job)   .. batch version
%
%  job
%   .files        .. Cell of XML file names or structure in a cell
%   .fname        .. Filename of the csv to be written 
%   .fieldnames   .. Selective field keywords that should be extracted, ie. 
%                    only fields that inlclude these strings are used.
%                    Allow also the coded selction of full fields, eg. 
%                    (defaut = {} i.e. include all) 
%   .avoidfields  .. Deselective field keywords to avoid fields, ie. all
%                    fields that inlcude these strings are not used.
%                    (default = {'help catlog'})
%   .report       .. report-setting ('default','paraonly','nopara')
%   .delimiter    .. Deliminiter of CSV file (default = ',')
%   .dimlim       .. Limit the number of matrix values (default = 256) 
%   
%  table .. cell table with structure path as header.  
%  
% For conversion to MATLAB table use:
%   cell2table(tab(2:end,:),'VariableNames',tab(1,:))
%
% Examples: 
%  * Export structure:
%    S = struct('files',{'A','B','C'},'data',[0.2 0.3 0.1],'mat',[0.3 0.4 0.2]);
%    table = cat_io_xml2csv_boney(struct('files',{{S}}));
%
%  * CAT XML files: 
%    table = cat_io_xml2csv_boney
%
% See also cat_io_struct2table.
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Id$
%
%#ok<*WNOFF,*WNON,*ASGLU>

  if ~exist('job','var'), job = 'GUI'; end

  def.files       = {};
  def.fname       = 'CATxml.csv'; 
  def.fieldnames  = {};
  def.avoidfields = {'help'; 'catlog'};
  def.delimiter   = ',';
  def.outdir      = {''}; 
  def.dimlim      = 256; % extend in case of catROI below
  def.report      = 'default';
  def.verb        = 1; 



  % TODO: 
  % - define some special user-cases for the cat_*.xml?
  % - setup for CSV / TSV export?
  % - write error in case of too large matrices
  % - dependencies



  % GUI
  if ischar(job) && strcmp(job,'GUI')
    clear job; 
    job.files       = cellstr(spm_select([1 inf],'any','Select *.xml files',{},pwd,'.*.xml$'));
    job.fname       = spm_input('CSV-filename',1,'s',def.fname); 
    job.dimlim      = spm_input('Limit matrix size',2,'n', def.dimlim,1);
    job.verb        = 1; 
    job.fieldnames  = spm_input('Selective field keywords? (*=all)',3,'s','*'); 
    job.avoidfields = spm_input('Deselective field keywords?',4,'s',''); 
    
    if strcmp(job.fieldnames,'*'), job.fieldnames = ''; end

    if ~isempty(job.fieldnames)
      job.fieldnames  = textscan( job.fieldnames  , '%s' );
      job.fieldnames  = cellstr(job.fieldnames{1}); 
    else
      job.fieldnames  = {};
    end
    if ~isempty(job.avoidfields)
      job.avoidfields = textscan( job.avoidfields , '%s' ); 
      job.avoidfields = cellstr(job.avoidfields{1}); 
    else
      job.avoidfields = {};
    end
  else
    % ########### check files? ###############
    % - what is about mat files such as the SPM mat8 ? 
  end


  % defaults
  job = cat_io_checkinopt(job,def);


  if job.verb
    spm('FnBanner',mfilename);
  end

  if isempty(job.files) || isempty(job.files{1})
    return
  end
  

  %% read all XML files
  if isstruct( job.files{1} )
    xml = job.files{1}; 
  else
    xml = cat_io_xml(job.files);
  end
  
  % get fieldnames
  fieldnames = getFN(xml,job.dimlim);

  % detect special XML cases 
  % - in case of the catROI(s)-files, we do not want to output the name/id
  %   fields as columnes, that are equal for all subjects, but as part of 
  %   the header
  % - in case of the cat-report-files, we want to avoid some development 
  %   fields
  [~,Sf] = spm_str_manip(job.files,'tC');
  Sf.sx  = strsplit(Sf.s,'_');
  if isempty(Sf.sx), xmltype = ''; else, xmltype = Sf.sx{1}; end
  switch xmltype
    case {'catROI','catROIs'} 
      % remove special fields in case of ROI XML files
      job.avoidfields = [ job.avoidfields; {'names';'ids'} ];
      job.dimlim = 1024;
  
    case 'cat'
      job.avoidfields = [ job.avoidfields; {'help'; 'catlog'; 'error'; 'hardware'; ...
        'parameter.extopts.atlas'; 'parameter.extopts.satlas'; 'parameter.extopts.LAB'; ...
        'parameter.extopts.shootingtpms{02}'; 'parameter.extopts.shootingtpms{03}'; 'parameter.extopts.shootingtpms{04}'; 'parameter.extopts.shootingtpms{05}'; ...
        'parameter.extopts.templates{02}'; 'parameter.extopts.templates{03}'; 'parameter.extopts.templates{04}'; 'parameter.extopts.templates{05}'; ...
        'filedata.Fm'; 'filedata.Fp0'; 'filedata.file'; 'filedata.fname'; 'filedata.fnames'; 'filedata.path'; ...
        'subjectmeasures.dist_thickness_kmeans_inner3'; 'subjectmeasures.dist_thickness_kmeans_outer2'; ...
        }];
      job.dimlim = 10;

      % remove developer fields
      if cat_get_defaults('extopts.expertgui')<2
        job.avoidfields = [ job.avoidfields; {'ppe'}; ]; 
      end

      % strong selection of most relevant fields 
      relevant_catreport_fields = ....
        {'qualityratings.IQR'; 'qualityratings.NCR'; 'qualityratings.ICR'; 'qualityratings.res_ECR'; 'qualityratings.res_RMS'; ... voxel-based QC measures
         'software.version_cat'; 'software.revision_cat'; 'software.version_spm'; ...
         ... 'qualitymeasures.SurfaceEulerNumber'; 'qualitymeasures.SurfaceDefectArea' ; ...
         'subjectmeasures.vol_abs_CGW(01)'; 'subjectmeasures.vol_abs_CGW(02)'; 'subjectmeasures.vol_abs_CGW(03)'; ...
         'subjectmeasures.vol_rel_CGW(01)'; 'subjectmeasures.vol_rel_CGW(02)'; 'subjectmeasures.vol_rel_CGW(03)'; ...
         'subjectmeasures.dist_thickness_kmeans'; 'subjectmeasures.surf_TSA'; 'subjectmeasures.vol_TIV'}; 


      switch job.report
        case 'paraonly'
          job.fieldnames = [job.fieldnames; {'opts'; 'extopts' }]; 
        case 'nopara'
          job.fieldnames = [job.fieldnames; relevant_catreport_fields ]; 
        case 'default'
          job.fieldnames = [job.fieldnames; relevant_catreport_fields; {'opts'; 'extopts' }]; 
      end


    otherwise
      job.avoidfields = [ job.avoidfields; {'help'; 'catlog'} ];
  end
  job.avoidfields(isempty(job.avoidfields)) = []; 
  job.fieldnames = unique(job.fieldnames); 

  % select fields
  if ~isempty(job.fieldnames) && (~isempty(job.fieldnames{1}) || numel(job.fieldnames)>1)
    selfieldnames = false(size(fieldnames));
    for fni = 1:numel(job.fieldnames)
      if ~isempty(job.fieldnames{fni})
        selfieldnames = selfieldnames | contains(fieldnames,job.fieldnames{fni});
      end
    end
    fieldnames = fieldnames(selfieldnames);
  end  
  
  % remove critical fieldnames
  for fni = 1:numel(job.avoidfields)
    if ~isempty(job.avoidfields{fni})
      rmfieldnames = contains(fieldnames,job.avoidfields{fni}); 
      fieldnames(rmfieldnames) = [];  
    end
  end

  if job.verb
        % some report for error handling
    %   # data
    fprintf('  Found/prepared %d fields of %d %s files.\n',numel(fieldnames), numel(job.files), xmltype);
  end
  if isempty(fieldnames)
    fprintf('  Nothing to export - no file written.\n');
    return; 
  end



  %% extract fieldnames from structure to build a table 
  [hdr,tab] = cat_io_struct2table(xml,fieldnames,0); 


  % add index
  fieldnames = ['filenames'; fieldnames];
  hdr = [{'filename'} hdr];
  tab = [job.files    tab];


  % cleanup some fields
  ROInamelim = 30; 
  for hi = 2:numel(hdr)
    if (strcmp(xmltype,'catROI') || strcmp(xmltype,'catROIs')) && contains(fieldnames(hi),'.data.') 
      FNP = strsplit(fieldnames{hi},'.');
      ATL = FNP{1};
      RNR = strsplit(cat_io_strrep(FNP{end},{'(',')','{','}'},' '));
      RNR = round(str2double(RNR{2})); %RNR{2};
      if isfield(xml(1).(ATL),'names') && ... % if there is a name ... 
          size(char(xml(1).(ATL).names),2)<ROInamelim % ... and if it is not too long
        ROI = ['_' strrep(xml(1).(ATL).names{RNR}(1:min(numel(xml(1).(ATL).names{RNR}),ROInamelim)),' ','_')]; 
      elseif isfield(xml(1).(ATL),'ids') && hi~=RNR
        ROI = ['_RID' num2str(xml(1).(ATL).ids(RNR))]; 
      else
        ROI = ''; 
      end
    else
      ROI = '';
    end

    hdr{hi} = cat_io_strrep(hdr{hi},{'(','{','['},''); 
    hdr{hi} = cat_io_strrep(hdr{hi},{')','}',']'},'_'); 
    if hdr{hi}(end)=='_', hdr{hi}(end) = []; hdr{hi} = [hdr{hi} ROI]; end
  end
  table = [hdr;tab];

 


  %% export table
  if ~isempty(job.fname)
    pp = spm_fileparts(job.fname); 
    if isempty(pp) 
      if isempty(job.outdir{1})
        fname = fullfile(pwd,job.fname);
      else
        fname = fullfile(job.outdir{1},job.fname);
      end
    else
      fname = job.fname; 
    end
    
    % replace critical characters
    for i=1:numel(table)
      if ischar(table{i})
        table{i} = strrep(table{i},'\\',''); % in case of filenames
        table{i} = strrep(table{i},'\','\\'); % in case of filenames
        table{i} = strrep(table{i},'%','\%'); % 
        table{i} = strrep(table{i},job.delimiter,setdiff(',;',job.delimiter)); 
      end
    end

    % write file
    cat_io_csv(fname,table,'','',struct('delimiter',job.delimiter,'komma','.'))

    if job.verb
      fprintf('  Wrote a %dx%d table in "%s".\n',size(table,1)-1,size(table,2),fname);
    end
  end


  %if isfield(job,'process_index') && job.verb, fprintf('Done\n'); end
  
  % worspace export
  if nargout > 0 || isempty(job.fname)
    varargout{1} = table; 
  end
end
% =========================================================================
function FNS = getFN(SS,dimlim)
%getFN(S). Recursive extraction of structure elements as string to eval. 

  if ~exist('dimlim','var'), dimlim = 10; end

  if isempty(SS)
    FNS = SS;
  else
    S   = SS(1);
    FN  = fieldnames(S);
    FNS = {};
    for fni = 1:numel(FN)
      % need this for useful order of fields
      acc = num2str( 1 + round( log10( numel( S.(FN{fni}) ))) );

      if isstruct( S.(FN{fni}) )
        % recursive call in case of structures
        FNI = getFN(S.(FN{fni}),dimlim); 
        if numel(S.(FN{fni})) == 1
          for fnii = 1:numel(FNI)
            FNI{fnii} = [FN{fni} '.' FNI{fnii}]; 
          end
        else
          FNI = {};
          for fnii = 1:numel(FNI)
            for sii = 1:numel(S.(FN{fni}))
              FNI = [FNI; sprintf(['%s(%0' acc 'd).%s'], FN{fni}, sii, FNI{fnii})]; %#ok<AGROW> 
            end
          end
        end
      elseif ischar( S.(FN{fni}) ) 
        FNI{1} = sprintf('%s', FN{fni} ); 
      elseif iscellstr( S.(FN{fni}) ) %#ok<ISCLSTR> 
        FNI = {};
        for fnii = 1:min(dimlim,numel( S.(FN{fni}) ))
          FNI = [FNI; sprintf(['%s{%0' acc 'd}'],FN{fni},fnii) ]; %#ok<AGROW> 
        end
      else
        if numel( S.(FN{fni}) ) == 1
          FNI{1} = sprintf('%s',FN{fni});
        else
          % just extract a limited number of elements
          FNI = {};
          for fnii = 1:min(dimlim,numel( S.(FN{fni}) ))
            FNI = [FNI; sprintf(['%s(%0' acc 'd)'],FN{fni},fnii) ]; %#ok<AGROW> 
          end
        end
      end
      FNS = [FNS; FNI]; %#ok<AGROW> 
    end
    FNS = unique(FNS);
  end
end


