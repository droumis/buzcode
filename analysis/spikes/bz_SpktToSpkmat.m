function [spikemat] = bz_SpktToSpkmat(spikes, varargin)
%spikemat = SpktToSpkmat(spiketimes,<options>) takes a 
% 1 x N_neurons cell array of spiketimes  and converts into a t/dt x N spike
% matrix.
%
%INPUTS
%   spikes      a structure with fields spikes.times
%               can also take a {Ncells} cell array of [spiketimes]
%               or [spiketimes, UID] pairs
%
%       (options)
%       'dt'        time step (default: 0.1s)
%       'binsize'   size of your time bins, in seconds (default: =dt)
%                   NOTE: must be a multiple of dt.
%       'win'       [start stop] time interval of the recording in which 
%                   to get spike matrix
%                   
%
%OUTPUT
%   spikemat
%       .data
%       .timestamps
%       .dt
%       .binsize
%
%Return:
%Spike Matrix
%time vector
%Spike time/cell indices for plotting
%
%To Do:
%   -Remove for loop... don't need to go through structure.
%   -T is just silly... make this a reasonable time window able to select
%   only spikes within a given time
%
%
%DLevenstein 2015. Updated 2018 for buzcode
%NOTE: in progres...
%TODO: update to use movmean/movsum
%% Options
p = inputParser;
addParameter(p,'win',[]);
addParameter(p,'binsize',[]);
addParameter(p,'overlap',[]);
addParameter(p,'dt',0.1);


parse(p,varargin{:})

win = p.Results.win;
binsize = p.Results.binsize;
overlap = p.Results.overlap;
dt = p.Results.dt;

%For legacy use of 'binsize','overlap' input
if ~isempty(binsize) && ~isempty(overlap)
    dt = binsize./overlap;
end

if isempty(binsize)
    binsize = dt;
end

if isempty(overlap)
    overlap = binsize./dt;
end


%% Deal With Input Type Variability

%If spiketimes is in a buzcode structure
if isstruct(spikes)
    spiketimes = spikes.times;
else
    spiketimes = spikes;
end

%If spike times is in the form [spiketimes(:,1) cellnum(:,2)], convert to
%cell array
if isa(spiketimes,'numeric') && size(spiketimes,2)==2
    cellnums = unique(spiketimes(:,2));
    for cc = cellnums'
        spiketimestemp{cc} = spiketimes(spiketimes(:,2)==cc,1);
    end
    spiketimes = spiketimestemp;
end

%Take stock of the cells - if there are no cells that's silly, but doesn't
%break.
numcells = length(spiketimes);
if numcells == 0
    spkmat=[];t=[];spindices=[];
    return
end


%Time Window
if isempty(win) || isequal(win,[0 Inf])
    t_start = 0; t_end = max(vertcat(spiketimes{:}));
elseif  length(win) == 2
    t_start = win(1); t_end = win(2);
end

%% The Meat of the function

numts = ceil((t_end-t_start)/dt);

%Remove spikes after t_end and before t_start (t_offset+t_start)
spiketimes = cellfun(@(x) x((x<t_end)),spiketimes,'UniformOutput',false);
spiketimes = cellfun(@(x) x((x>t_start)),spiketimes,'UniformOutput',false);


%Establish Cell Structure... maybe do this with cellfun... or
%cell2struct
cells = cell2struct(spiketimes,'spiketimes',1);
for cell_ind = 1:numcells
    %When Spike? row index for each spike
    cells(cell_ind).spiketimes = cells(cell_ind).spiketimes';
    %Which Cell? column index for each spike
    cells(cell_ind).index4spikes = cell_ind*ones(size(cells(cell_ind).spiketimes));
end

%Make a Spike Matrix
spkmat = zeros(numts,numcells,'single');
%Spike Indices - time
spikes_ind_t = ceil(([cells.spiketimes]-t_start)/dt); 
spikes_ind_t(find(spikes_ind_t==0)) = 1;
%Spike Indices - cell
spikes_ind_c = [cells.index4spikes];


%Spike Indices - convert to linear index
spikes_ind = sub2ind(size(spkmat), spikes_ind_t,spikes_ind_c);

%Add Spikes to bins of size dt
while spikes_ind
    spkmat(spikes_ind) = spkmat(spikes_ind)+1;
    %Remove full bins
    [uniquespikes, unisp_ind] = unique(spikes_ind);
    spikes_ind(unisp_ind) = [];
end

t = [0:size(spkmat,1)-1]'*dt+0.5*dt+t_start; %time vector (midpoint)

% Moving sum to combine spikes into bins of size binsize
spkmat = movsum(spkmat,overlap);
t = movmean(t,overlap); %timepoint in the resulting bin is the mean of 
                        %timepoints from all bins added

spikemat.data = spkmat;
spikemat.timestamps = t;
spikemat.dt = dt;
spikemat.binsize = binsize;

end

