function [v_,psnr_,ssim_,t_,psnrall] = admmdenoise_cacti( ...
    mask,meas,orig,v0,para)
%ADMMDENOISE_CACTI ADMM-Denoise frame for recontruction of  CACTI 
%high-speed imaging.
%   See also ADMMDENOISE, TEST_ADMMDENOISE.
iframe   = 1; % start frame number
projmeth = 'admm'; % projection method (ADMM for default)
maskdirection  = 'plain'; % direction of the mask
if isfield(para,'iframe');     iframe = para.iframe; end
if isfield(para,'projmeth'); projmeth = para.projmeth; end
if isfield(para,'maskdirection'); maskdirection = para.maskdirection; end
if isempty(orig); para.flag_iqa = false; end
[nrow,ncol,nmask]  = size(mask);
nframe = para.nframe;
MAXB   = para.MAXB;

psnrall = [];
% ssimall = [];
v_ = zeros([nrow ncol nmask*nframe],'like',meas);
tic
% coded-frame-wise denoising
time_start = tic;
for kf = 1:nframe
%     fprintf('%s-%s Reconstruction frame-block %d of %d ...\n',...
%         upper(para.projmeth),upper(para.denoiser),kf,nframe);
    fprintf('%s-%s Reconstruction frame-block %d of %d ...\n',...
        upper(projmeth),upper(para.denoiser),kf,nframe);	
    if ~isempty(orig)
        para.orig = orig(:,:,(kf-1+iframe-1)*nmask+(1:nmask))/MAXB;
    end
    y = meas(:,:,kf+iframe-1)/MAXB;
    if isempty(v0) % raw initialization
        para.v0 = [];
    else % given initialization
        switch lower(maskdirection)
            case 'plain'
                para.v0 = v0(:,:,(kf-1)*nmask+(1:nmask));
            case 'updown'
                if mod(kf+iframe-1,2) == 0 % even frame (falling of triangular wave)
                    para.v0 = v0(:,:,(kf-1)*nmask+(1:nmask));
                else % odd frame (rising of triangular wave)
                    para.v0 = v0(:,:,(kf-1)*nmask+(nmask:-1:1));
                end
            case 'downup'
                if mod(kf+iframe-1,2) == 1 % odd frame (rising of triangular wave)
                    para.v0 = v0(:,:,(kf-1)*nmask+(1:nmask));
                else % even frame (falling of triangular wave)
                    para.v0 = v0(:,:,(kf-1)*nmask+(nmask:-1:1));
                end
            otherwise
                error('Unsupported mask direction %s!',lower(maskdirection));
        end
    end
    switch lower(projmeth)
        case 'gap' % GAP-Denoise
            if isfield(para,'wnnm_int') && para.wnnm_int % GAP-WNNM integrated
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = gapwnnm_int(y,para);
                else
                    [v,psnrall(kf,:)] = gapwnnm_int(y,para);
                end
            elseif isfield(para,'wnnm_int_fwise') && para.wnnm_int_fwise % GAP-WNNM integrated (with frame-wise denoising)
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = gapwnnm_int_fwise(y,para);
                else
                    [v,psnrall(kf,:)] = gapwnnm_int_fwise(y,para);
                end
            else
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = gapdenoise(y,para);
                else
                    [v,psnrall(kf,:)] = gapdenoise(y,para);
                end
            end
        case 'admm' % ADMM-Denoise
            if isfield(para,'wnnm_int') && para.wnnm_int % GAP-WNNM integrated
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = admmwnnm_int(y,para);
                else
                    [v,psnrall(kf,:)] = admmwnnm_int(y,para);
                end
            elseif isfield(para,'wnnm_int_fwise') && para.wnnm_int_fwise % GAP-WNNM integrated (with frame-wise denoising)
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = admmwnnm_int_fwise(y,para);
                else
                    [v,psnrall(kf,:)] = admmwnnm_int_fwise(y,para);
                end
            else
                if isfield(para,'flag_iqa') && ~para.flag_iqa % ImQualAss disabled
                    v = admmdenoise(y,para);
                else
                    [v,psnrall(kf,:)] = admmdenoise(y,para);
					
                end
            end
        otherwise
            error('Unsupported projection method %s!',projmeth);
    end
    switch maskdirection
        case 'plain'
            v_(:,:,(kf-1)*nmask+(1:nmask)) = v;
        case 'updown'
            if mod(kf+iframe-1,2) == 0 % even frame (falling of triangular wave)
                v_(:,:,(kf-1)*nmask+(1:nmask)) = v;
            else % odd frame (rising of triangular wave)
                v_(:,:,(kf-1)*nmask+(nmask:-1:1)) = v;
            end
        case 'downup'
            if mod(kf+iframe-1,2) == 1 % odd frame (rising of triangular wave)
                v_(:,:,(kf-1)*nmask+(1:nmask)) = v;
            else % even frame (falling of triangular wave)
                v_(:,:,(kf-1)*nmask+(nmask:-1:1)) = v;
            end
        otherwise 
            error('Unsupported mask direction %s!',lower(maskdirection));
	end
	time_now = toc;
	fprintf('--> finish: %d/%d frames	total time: %.2f', kf, nframe, (time_now-time_start)/60)
end
t_ = toc;
% image quality assessments
psnr_ = zeros([1 nmask*nframe]);
ssim_ = zeros([1 nmask*nframe]);
if ~isempty(orig)
    for kv = 1:nmask*nframe
        psnr_(kv) = psnr(double(v_(:,:,kv)),double(orig(:,:,kv+(iframe-1)*nmask)/MAXB),max(max(max(double(orig(:,:,kv))/MAXB))));
        ssim_(kv) = ssim(double(v_(:,:,kv)),double(orig(:,:,kv+(iframe-1)*nmask)/MAXB));
    end
end

end

