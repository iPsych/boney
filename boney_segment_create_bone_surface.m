function [Si, Stm, sROI] = boney_segment_create_bone_surface ...
  (Vo, Ybonepp, Ybonemarrow, Ybonethick, Yheadthick, Ya, Ymsk, YaROIname, out, job)
%create_bone_surface. Surface-based processing pipeline.
% Final bone processing function that creates the bone surfaces to extract
% values from the surrounding bone tissue. It uses the percentage position
% map Ybonepp that runs in the middle of the bone and maps the thickness
% map Ybonethick on it.
% In additon, the thickness map of the head is also mapped.
%
%
%  [Si, Stm, sROI] = boney_segment_create_bone_surface(Vo, ...
%    Ybonepp, Ybonemarrow, Ybonethick, Yheadthick, Ya, Ymsk, out, job)
%
%  Si          .. bone intensity surface
%  Stm         .. bone thickness surface with regional boundaries
%  sROI        ..
%
%  Vo          .. original file header
%  Ybonepp     .. percentage map of the bone (0-head to 1-brain)
%  Ybonemarrow .. bone marrow map (masked normalized image)
%  Ybonethick  .. bone thickness map
%  Yheadthick  .. head thickness map
%  Ya          .. bone atlas map (major regions)
%  Ymsk        .. bone mask map (to avoid bad regions)
%  out         .. main results
%  job         .. main parameters
% _________________________________________________________________________
%
% Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% _________________________________________________________________________


  % surface coordinate transformation matrix
  matlab_mm  = Vo.mat * [0 1 0 0; 1 0 0 0; 0 0 1 0; 0 0 0 1];   % CAT internal space
  vx_vol     = sqrt(sum(Vo.mat(1:3,1:3).^2)) ;


  %% == create surface ==
  %  Worked best for the already smooth Ybonepp map and additional strong
  %  surface smoothing. Surface deformation was not helpful.
  if 1
    [Yboneppr,res] = cat_vol_resize(smooth3(Ybonepp),'reduceV',vx_vol,job.opts.reduce,6,'meanm'); %#ok<ASGLU>
    txt = evalc(sprintf('[Yppc,CBS.faces,CBS.vertices] = cat_vol_genus0(Yboneppr,.5,0);')); %#ok<NASGU>
    CBS.vertices = CBS.vertices .* repmat(res.vx_red * [0 1 0; 1 0 0; 0 0 1],size(CBS.vertices,1),1) ... 
      - repmat((res.vx_red * [0 1 0; 1 0 0; 0 0 1]-1)/2,size(CBS.vertices,1),1); %#ok<NODEF> 
    CBS = cat_surf_fun('smat',CBS,matlab_mm); % transform to mm
    CBS.EC = size(CBS.vertices,1) + size(CBS.faces,1) - size(spm_mesh_edges(CBS),1);
    saveSurf(CBS,out.P.central);
  
    % optimize surface for midbone position by simple blurring
    % simple smoothing to remove stair artifacts - 8-16 iterations in red 2
    cmd = sprintf('CAT_BlurSurfHK "%s" "%s" %d', out.P.central ,out.P.central, 16 );
    cat_system(cmd,0);
  else
      cmd = sprintf('CAT_VolMarchingCubes -pre-fwhm "-1" -post-fwhm "1" -thresh "%g" "%s" "%s"',th_initial,Vpp_side.fname,Pcentral);
      cat_system(cmd,opt.verb-3);

      % Collins-without: 2.5996 ± 0.6292 mm, 0.0798 / 0.1096, 10.29% (121.38 cm²) 24.19% (285.46 cm²)
      % Collins-with:    2.5713 ± 0.6525 mm, 0.0723 / 0.0934,  8.51% (98.93 cm²)  23.79% (276.42 cm²)
      cmd = sprintf(['CAT_DeformSurf "%s" none 0 0 0 "%s" "%s" none  0  1  -1  .1 ' ...           
                  'avg  -0.1  0.1 .2  .1  5  0 "0.5"  "0.5"  n 0  0  0 %d  %g  0.0 0'], ...    
                  Vpp_side.fname,Pcentral,Pcentral,50,0.001);
      cat_system(cmd,opt.verb-3);
  end

    CBS = loadSurf(out.P.central);

  % create a (smoothed) thickness map for the mapping extracted values from the bone
  % .. however, the smoothing did not improve the mapping
  Ybonethick2 = cat_vol_approx(Ybonethick .* (Ybonethick>1 & Ybonethick<100),'nh',1,3);
  Si = CBS; Si.facevertexcdata = cat_surf_fun('isocolors',max(3,Ybonethick2), CBS, matlab_mm);
  cat_io_FreeSurfer('write_surf_data',out.P.thick,Si.facevertexcdata);



  % == map values ==
  % estimate the local minimum to get the hard bone (cortex)
  bonemed      = cat_stat_nanmedian(Ybonemarrow(Ybonepp>0 & Ybonepp<1));
  Ybonemarrow3 = Ybonemarrow; Ybonemarrow3(Ybonepp==0 | Ybonepp==1) = bonemed; % limit by median
  Vppmin       = cat_io_writenii(Vo, Ybonemarrow3 , '', 'skull.bone' ,'bone', 'single', [0,1],[1 0 0],struct());
  mappingstr   = sprintf('-linear -min -steps "9" -start "-.5" -end ".5" -thickness "%s" ', out.P.thick); % min - larger range to assure minimum
  cmd          = sprintf('CAT_3dVol2Surf %s "%s" "%s" "%s" ',mappingstr, out.P.central,  Vppmin.fname , out.P.cortex );
  cat_system(cmd,0); delete(Vppmin.fname);
  cortex       = min( cat_stat_nanmedian(Ybonemarrow3(Ybonepp>0 & Ybonepp<1)) , cat_io_FreeSurfer('read_surf_data',out.P.cortex));

  % estimate maximum for bone marrow with full range
  % ######## RD20230831: just for tests.
  Vpp          = cat_io_writenii(Vo, Ybonemarrow , '', 'skull.marrow' ,'bone marrow', 'single', [0,1],[1 0 0],struct());
  mappingstr   = sprintf('-linear -max -steps "9" -start "-.5" -end ".5" -thickness "%s" ', out.P.thick); % weighted_avg
  cmd          = sprintf('CAT_3dVol2Surf %s "%s" "%s" "%s" ',mappingstr, out.P.central,  Vpp.fname , out.P.marrow );
  cat_system(cmd,0); delete(Vpp.fname);
  marrowmax    = cat_io_FreeSurfer('read_surf_data',out.P.marrow);

  % estimate average for bone marrow with even limited range
  if 1
    Vpp          = cat_io_writenii(Vo, Ybonemarrow , '', 'skull.marrow' ,'bone marrow', 'single', [0,1],[1 0 0],struct());
    mappingstr   = sprintf('-linear -weighted_avg -steps "5" -start "-.5" -end ".5" -thickness "%s" ', out.P.thick); % weighted_avg
    cmd          = sprintf('CAT_3dVol2Surf %s "%s" "%s" "%s" ',mappingstr, out.P.central,  Vpp.fname , out.P.marrow );
    cat_system(cmd,0); delete(Vpp.fname);
    Si.facevertexcdata = cat_io_FreeSurfer('read_surf_data',out.P.marrow);
  else
    Si.facevertexcdata = marrowmax;
  end

  % get atlas information
  for ai = 1 %:numel(Ya)
    Satlas{ai} = cat_surf_fun('isocolors',Ya{ai}, CBS, matlab_mm,'nearest');
    Si.facevertexcdata = single(Si.facevertexcdata .* (Satlas{ai}>0));
    cat_io_FreeSurfer('write_surf_data',out.P.thick,Si.facevertexcdata);
  end

  if 0 %#ok<*UNRCH>
    %% only for debugging and tests!
    Sh  = cat_surf_render2(Si);                                          cat_surf_render2('Clim',Sh,[0 6]); cat_surf_render2('Colorbar',Sh); title('soft')
    Stx = Si; Stx.facevertexcdata = cortex; Sh = cat_surf_render2(Stx);  cat_surf_render2('Clim',Sh,[0 3]); cat_surf_render2('Colorbar',Sh);  title('hard')
  end



  %% get peak bone threshold
  % -use of nan for unwanted rois ?
  Si.vertices = CBS.vertices; Si.faces = single(CBS.faces); St = Si; Stm = Si; Sth = Si;
  for ai = 1:numel(Ya)
    S.atlas{ai} = cat_surf_fun('isocolors',Ya{ai}      , CBS, matlab_mm, 'nearest');
  end
  S.mask      = cat_surf_fun('isocolors',single(Ymsk), CBS, matlab_mm) > .5;
  S.thick     = cat_surf_fun('isocolors',Ybonethick  , CBS, matlab_mm);
  S.hdthick   = cat_surf_fun('isocolors',Yheadthick  , CBS, matlab_mm);
  St.facevertexcdata  = S.thick;
  Sth.facevertexcdata = S.hdthick;

  % thickess with atlas borders
  Stm.facevertexcdata = S.thick .* cat_surf_fun('isocolors',max(.1,1 - (cat_vol_grad(Ya{1}*1000)>0.1) * .9 ),CBS, matlab_mm);



  %% global + regional measures as column elements
  %  ----------------------------------------------------------------------
  %  - similar to the volume measures we also focus here on the global/
  %    regional mean values and ignore median, std, and iqr
  for ai = 1:numel(Ya)
    rii = 1;
    sROI(ai).file = '';
    sROI(ai).help = [
        'A masked image is used for global values to extract only the upper part of the skull, ' ...
        'whereas no masking is used in case of atlas regions. '];
    for ri = 0:max(Ya{ai}(Ya{ai}(:)<intmax('uint16'))) % region ri==0 is the global value
      if ri == 0 || isnan(ri)
        ri = 0; %#ok<FXSET> % case of failed atlas mapping
        sROI(ai).boneatlas_id(1,rii)       = inf;
        sROI(ai).nonnanvol(1,rii)          = sum(S.atlas{ai}>intmax('uint16')) ./ numel(S.atlas{ai});
        if ~isempty( job.opts.Pmask{1} ),    sROI(ai).boneatlas_name{1,rii} = 'full-masked';
        else,                                sROI(ai).boneatlas_name{1,rii} = 'full-unmasked';
        end
        sROI(ai).bonemarrow(1,rii)         = cat_stat_nanmean(Si.facevertexcdata(S.mask));
        sROI(ai).bonemarrowmax(1,rii)      = cat_stat_nanmean(marrowmax(S.mask));
        sROI(ai).bonecortex(1,rii)         = cat_stat_nanmean(cortex(S.mask));
        sROI(ai).bonethickness(1,rii)      = cat_stat_nanmean(S.thick(S.mask));
        sROI(ai).headthickness(1,rii)      = cat_stat_nanmean(S.hdthick(S.mask));
        rii = rii + 1;
      else
        if sum(S.atlas{ai}==ri)>0
          sROI(ai).boneatlas_id(1,rii)     = ri;
          if isempty(YaROIname) && isempty(YaROIname{ai}) %|| numel(YaROIname)>max(Ya(Ya(:)<intmax('uint16')))
            sROI(ai).boneatlas_name{1,rii} = sprintf('ROI%d',ri);
          else
            if rii <= numel(YaROIname{ai})
              sROI(ai).boneatlas_name{1,rii} = YaROIname{ai}{rii - 1};
            else
              sROI(ai).boneatlas_name{1,rii} = nan;
            end
          end
          sROI(ai).nonnanvol(1,rii)        = sum(S.atlas{ai}==ri) ./ numel(S.atlas{ai});
          sROI(ai).bonemarrow(1,rii)       = cat_stat_nanmean(Si.facevertexcdata(S.atlas{ai}==ri));
          sROI(ai).bonemarrowmax(1,rii)    = cat_stat_nanmean(marrowmax(S.atlas{ai}==ri));
          sROI(ai).bonecortex(1,rii)       = cat_stat_nanmean(cortex(S.atlas{ai}==ri));
          sROI(ai).bonethickness(1,rii)    = cat_stat_nanmean(S.thick(S.atlas{ai}==ri));
          sROI(ai).headthickness(1,rii)    = cat_stat_nanmean(S.hdthick(S.atlas{ai}==ri));
          rii = rii + 1;
        end
      end
    end
  end

end
% helping functions to load/write gifti surfaces
%=======================================================================
function saveSurf(CS,P)
  save(gifti(struct('faces',CS.faces,'vertices',CS.vertices)),P,'Base64Binary'); %#ok<USENS>
end
%=======================================================================
function CS1 = loadSurf(P)
  CS = gifti(P);
  CS1.vertices = CS.vertices; CS1.faces = CS.faces;
  if isfield(CS,'cdata'), CS1.cdata = CS.cdata; end
end
%=======================================================================
