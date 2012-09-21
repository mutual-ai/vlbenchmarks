classdef VlFeatCovdet < localFeatures.GenericLocalFeatureExtractor & ...
    helpers.GenericInstaller
% localFeatures.VlFeatCovdet VLFeat vl_covdet wrapper
%   VlFeatCovdet('OptionName',OptionValue,...) Creates new object which
%   wraps around VLFeat covariant image frames detector. All given options
%   defined in the constructor are passed directly to the vl_covdet 
%   function when called.
%
%   The options to the constructor are the same as that for vl_covdet
%   See help vl_covdet to see those options and their default values.
%
%   See also: vl_covdet

% Authors: Karel Lenc, Varun Gulshan

% AUTORIGHTS
  properties (SetAccess=public, GetAccess=public)
    Opts
    VlCovdetArguments
    BinPath
  end

  methods
    function obj = VlFeatCovdet(varargin)
      import helpers.*;
      % def. arguments
      vlArgs.method = 'DoG';
      vlArgs.affineAdaptation = false;
      [vlArgs, drop] = vl_argparse(vlArgs,varargin);
      obj.Name = ['VLFeat ' vlArgs.method];
      if vlArgs.affineAdaptation, obj.Name = [obj.Name '-affine']; end
      obj.DetectorName = obj.Name;
      obj.DescriptorName = 'VLFeat SIFT';
      obj.ExtractsDescriptors = true;
      obj.Opts.forceOrientation = false; % Force orientation for SIFT desc.
      [obj.Opts varargin] = vl_argparse(obj.Opts,varargin);
      varargin = obj.checkInstall(varargin);
      % Rest of the arguments use as vl_covdet arguments
      obj.VlCovdetArguments = obj.configureLogger(obj.Name,varargin);
      obj.BinPath = {which('vl_covdet') which('libvl.so')};
    end

    function [frames descriptors] = extractFeatures(obj, imagePath)
      import helpers.*;
      [frames descriptors] = obj.loadFeatures(imagePath,nargout > 1);
      if numel(frames) > 0; return; end;
      img = imread(imagePath);
      if(size(img,3)>1), img = rgb2gray(img); end
      img = single(img); % If not already in uint8, then convert
      startTime = tic;
      if nargout == 1
        obj.info('Computing frames of image %s.',getFileName(imagePath));
        [frames] = vl_covdet(img,obj.VlCovdetArguments{:});
      else
        obj.info('Computing frames and descriptors of image %s.',...
          getFileName(imagePath));
        [frames descriptors] = vl_covdet(img,obj.VlCovdetArguments{:});
      end
      timeElapsed = toc(startTime);
      obj.debug('Frames of image %s computed in %gs',...
        getFileName(imagePath),timeElapsed);
      obj.storeFeatures(imagePath, frames, descriptors);
    end
    
    function [frames descriptors] = extractDescriptors(obj, imagePath, frames)
      numValues = size(frames,1);
      if numValues < 3 || numValues > 6
        error('Invalid frames format');
      end
      hasAffineShape = numValues > 4;
      hasOrientation = numValues == 4 || numValues == 6;
      if nargin >= 3
        if obj.Opts.forceOrientation
          hasOrientation = true; % force calculating orientations
        end
      end
      image = imread(imagePath);
      if(size(image,3)>1), image = rgb2gray(image); end
      image = single(image); % If not already in uint8, then convert
      obj.info('Computing descriptors of %d frames.',size(frames,2));
      startTime = tic;
      [frames descriptors] = vl_covdet(image, 'Frames', frames,...
          'AffineAdaptation',hasAffineShape,'Orientation', hasOrientation);
      timeElapsed = toc(startTime);
      obj.debug('Descriptors of %d frames computed in %gs',...
        size(frames,2),timeElapsed);
    end

    function sign = getSignature(obj)
      sign = [helpers.fileSignature(obj.BinPath{:}) ';'...
              helpers.cell2str(obj.VlCovdetArguments)];
    end
  end

  methods (Access=protected)
    function deps = getDependencies(obj)
      deps = {helpers.VlFeatInstaller('0.9.15')};
    end
  end
end