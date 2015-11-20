function piv_bfield_stats(OPTIONS, dir_case)
%% This takes the filtered vectors from a directory of .mat files, and 
%  computes some statistics, then saving the stats in a new .mat file.

% get filenames of the .mat files
dir_vectors = [dir_case filesep 'vectors'];
files       = dir([dir_vectors filesep 'instantaneous' filesep '*.mat']);
fnames      = sort_nat({files.name}, 'ascend'); 	% sort the file list with natural ordering
fnames      = fnames(:);                        	% reshape into a nicer list

if isempty(fnames)
    error('[ERROR] The "instantaneous" directory contains no .mat files');
end

% determine stencil size for vorticity calculation method
switch OPTIONS.method_vort
    case 'circulation'
        offset = 2 - 1;
    case 'leastsq'
        offset = 3 - 1;
    otherwise
        error('[ERROR] unrecognized options for method_vort');
end


%% INSTANTANEOUS COMPONENTS U = u' + Umean
% it is assumed that pixels have been converted to meters 

% load the first image to know the size (MatPIV should replace isrgb with imfshow to determine if grayscale image)
% info_image = imfinfo([dir_images_post filesep fnames{1}]);

% load the first .mat file to determine size, and x-y coordinates
load([dir_vectors filesep 'instantaneous' filesep fnames{1}])

% load all .mat files into a single "stack", a 3D array
all_u     = zeros(size(x,1), size(x,2), numel(fnames));
all_v     = zeros(size(x,1), size(x,2), numel(fnames));
all_Umag  = zeros(size(x,1), size(x,2), numel(fnames));
all_wz    = zeros(size(x,1), size(x,2), numel(fnames));
for n = 1:numel(fnames)
    
    % load the .mat file of filtered and transformed data (expects specific variable names) 
    load([dir_vectors filesep 'instantaneous' filesep fnames{n}])
     
    % instantaneous variables
    all_u(:,:,n)    = fu;
    all_v(:,:,n)    = fv;
    all_Umag(:,:,n) = sqrt(fu.^2 + fv.^2);
    all_wz(:,:,n)   = fwz;
                
end


%% STATISTICS on INSTANTANEOUS variables
mean_u    = zeros(size(x,1), size(x,2));
mean_v    = zeros(size(x,1), size(x,2));
mean_Umag = zeros(size(x,1), size(x,2));
std_u     = zeros(size(x,1), size(x,2));
std_v     = zeros(size(x,1), size(x,2));
std_mag   = zeros(size(x,1), size(x,2));
rms_u     = zeros(size(x,1), size(x,2));
rms_v     = zeros(size(x,1), size(x,2));
rms_mag   = zeros(size(x,1), size(x,2));
mean_wz   = zeros(size(x,1), size(x,2));
for n = 1:size(x,1)
    for m = 1:size(x,2)

        mean_u(n,m)    = nanmean( all_u(n,m,:) );
        mean_v(n,m)    = nanmean( all_v(n,m,:) );
        mean_Umag(n,m) = nanmean( all_Umag(n,m,:) );
        
        std_u(n,m)   = nanstd( all_u(n,m,:) );
        std_v(n,m)   = nanstd( all_v(n,m,:) );
        std_mag(n,m) = sqrt(std_u(n,m,:).^2 + std_v(n,m,:).^2);
        
        rms_u(n,m)   = sqrt(mean(all_u(n,m,:).^2));
        rms_v(n,m)   = sqrt(mean(all_v(n,m,:).^2));
        rms_mag(n,m) = sqrt(rms_u(n,m,:).^2 + rms_v(n,m,:).^2);
        
        mean_wz(n,m) = nanmean( all_wz(n,m,:) );
    end
end
% save the statistics
par_save([dir_vectors filesep 'stats' filesep 'stats'], ...
          x, y, mean_u, mean_v, mean_Umag, ...
                std_u, std_v, std_mag, ...
                rms_u, rms_v, rms_mag, ...
                mean_wz);

% export as VTK files, compatible with ParaView and VisIt
z       = zeros(size(x));               % fake 3rd dimension coordinates
mean_w  = zeros(size(mean_u));          % fake 3rd dimension velocity
mean_wx = zeros(size(mean_wz));         % fake 1st dimension vorticity
mean_wy = zeros(size(mean_wz));         % fake 2nd dimension vorticity      
vtkwrite([dir_vectors filesep 'vtk' filesep 'vtk_mean_velocity.vtk'], ...
         'structured_grid',x,y,z, 'vectors','mean_velocity',mean_u,mean_v,mean_w)
vtkwrite([dir_vectors filesep 'vtk' filesep 'vtk_mean_vorticity.vtk'], ...
         'structured_grid',x,y,z, 'vectors','vorticity',mean_wx,mean_wy,mean_wz)

      
%% FLUCTUATING COMPONENTS ... P stand for "prime" like u'
all_uP    = zeros(size(x,1), size(x,2), numel(fnames));
all_vP    = zeros(size(x,1), size(x,2), numel(fnames));
all_UmagP = zeros(size(x,1), size(x,2), numel(fnames));
all_wzP   = zeros(size(x,1), size(x,2), numel(fnames));      
z   = zeros(size(x));         % fake 3rd dimension coordinate
fw  = zeros(size(x));         % fake 3rd dimension velocity
fwx = zeros(size(x));         % fake 1st dimension vorticity
fwy = zeros(size(x));         % fake 2nd dimension vorticity    
for n = 1:numel(fnames)
    
    all_uP(:,:,n)    = all_u(:,:,n) - mean_u;
    all_vP(:,:,n)    = all_v(:,:,n) - mean_v;
    all_UmagP(:,:,n) = sqrt(all_uP(:,:,n).^2 + all_vP(:,:,n).^2);
    
    % vorticity from the fluctuating components
    fwzP           = vorticity(x, y, all_uP(:,:,n), all_vP(:,:,n), OPTIONS.method_vort);
    all_wzP(:,:,n) = padarray(fwzP,[offset offset]);                % pad with zeros to make same size as velocity arrays
    
    
    % save fluctuating variables, the filtered and transformed vectors (even if no filtering/transform was performed, just so filenaming is consistent)
    uP  = all_uP(:,:,n);
    vP  = all_vP(:,:,n);
    wzP = all_wzP(:,:,n);
    par_save([dir_vectors filesep 'fluctuating' filesep 'fluctuating__' sprintf('%5.5d', n)], ...
             x, y, uP, vP, wzP)
         
    % export fluctuating variables as VTK files, compatible with ParaView and VisIt
    vtkwrite([dir_vectors filesep 'vtk' filesep 'vtk_velocity_fluctuating__' sprintf('%5.5d', n) '.vtk'], ...
             'structured_grid',x,y,z,'vectors', 'velocity',uP, vP, fw)  
    vtkwrite([dir_vectors filesep 'vtk' filesep 'vtk_vorticity_fluctuating__' sprintf('%5.5d', n) '.vtk'], ...
             'structured_grid',x,y,z,'vectors', 'vorticity',fwx,fwy,wzP)
         
end
      

%% More statistics on the fluctuating components

% MKE: mean flow kinetic energy 
% MKE = 0.5 * (mean(uP).^2 + mean(vP).^2);
% TKE: turbulent flow kinetic energy 
% TKE = 0.5 * (mean(uP.^2) + mean(vP.^2));

% these are all calculated from instantaneous values U = u' + uMean ?
ke_tot  =( rms_u.^2 +  rms_v.^2)/2;
ke_turb =( std_u.^2 +  std_v.^2)/2;
ke_mean =(mean_u.^2 + mean_v.^2)/2;

% plot(sm_frame*smooth,ke_tot,'r-', sm_frame*smooth,ke_turb,'b-', sm_frame*smooth,ke_mean,'m-');
% legend('E total','E turb','E mean');
% xlabel('field num');
% ylabel('E (m/s)^2');
% title('Total, turbulent, and mean kinetic energies');
% ax=ylim;
% ylim([0 max(ylim)]);



% Reynolds stress
% T is a symmetric matrix: T(i,j) = T(j,i).
%     The kinetic energy (per unit mass) is given by 2*trace(T).
%     For isotropic flow, T is proportional to the identity matrix.
% Rstress = -1 * mean(handles.uf .* handles.vf, 3); % Reynolds stress










%% Proper Orthogonal Decomposition (THIS IS NOT WORKING YET)
% on the mean of velocity magnitude

% if OPTIONS.POD
%     % this analysis cannot accept NaNs, so interpolate all NaNs out
%     for n = 1:numel(fnames)
%         [u_all(:,:,n), v_all(:,:,n)] = naninterp(u_all(:,:,n), v_all(:,:,n), 'linear', x_all, y_all);
%     end
% 
%     % create matrix will all fluctuating velocity components for each snapshot in a column
%     Uf   = u_all;
%     Vf   = u_all;
%     ni   = size(u_all,1);
%     nj   = size(u_all,2);
%     ns   = size(u_all,3);
%     Uall = [reshape(Uf,ni*nj,ns); ...
%             reshape(Vf,ni*nj,ns)];
% 
%     % Proper Orthogonal Decomposition analysis
%     R       = Uall' * Uall;     % Autocovariance matrix
%     [eV, D] = eig(R);           % solve: eV is eigenvectors, D is eigenvalues in diagonal matrix
%     [L, I]  = sort(diag(D));    % sort eigenvalues in ascending order - I is sorted index vector
% 
%     for i=1:length(D)
%         eValue(length(D)+1-i) = L(i);           % Eigenvalues sorted in descending order (lambda_n)
%         eVec(:,length(D)+1-i) = eV(:,I(i));     % Eigenvectors sorted in the same order (Ai)
%     end
% 
%     eValue(length(eValue)) = 0;                     % last eigenvalue should be zero
%     menergy                = eValue/sum(eValue);    % relative energy associated with mode m
% 
%     figure
%     % histogram(menergy)
%     bar(menergy)
% 
% 
% 
%     N_MODES = 3;
%     for i=1:N_MODES
%         tmp      = Uall*eVec(:,i);  % find mode
%         phi(:,i) = tmp/norm(tmp);   % normalize mode (POD modes)
%     end
% 
%     N_COMPONENTS = 2;   % number velocity components
%     phi1 = reshape(phi(:,1), ni, nj, N_COMPONENTS);     % the POD mode 1
%     phi2 = reshape(phi(:,2), ni, nj, N_COMPONENTS);     % the POD mode 2
% 
%     % a coefficiencts of u-v-components from snapshot 1 (from POD mode 1)
%     a_1_u  = phi1(:,:,1) * u_all(:,:,1);    % u-component
%     a_1_v  = phi1(:,:,2) * v_all(:,:,1);    % v-component
% 
%     % a coefficiencts of u-v-components from snapshot 1 (from POD mode 2)
%     a_2_u  = phi2(:,:,1) * u_all(:,:,1);    % u-component
%     a_2_v  = phi2(:,:,2) * v_all(:,:,1);    % v-component
% 
%     % reconstructed u-v-components from POD mode 1
%     u_recon_1  = a_1_u * phi1(:,:,1);
%     v_recon_1  = a_1_v * phi1(:,:,2);
% 
%     % reconstructed u-v-components from POD modes 1,2,4
%     u_recon_124  = a_1_u * phi1(:,:,1);
%     v_recon_124  = a_1_v * phi1(:,:,2);
% 
%     figure
%     cmap = bipolar(21, 0.51);     
%     contourf(x, y, u_recon_1);
%     contourf(x, y, v_recon_1);
%     colormap(cmap)
%     colorbar
% 
% 
%     reshape(u_recon_1,ni,nj)
% end 


end % function

