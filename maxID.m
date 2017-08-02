
% function that detrends, then finds maximum values of each spike

% things to fix: 
% - the threshold for spikes of >75% of standard deviation is arbitrary, and might be too 
%   high or low depending on the noise in the data (maybe? perhaps stddev adapts accordingly)
% - the indices are currently all OK, but are quite tricky to think through -- editing a challenge?
% - using the initial polynomial fit as a reference might be too arbitrary
% - manipulate the degree of the polynomial fit, the 0.5 stddev cutoff for despiking, and the requirements
%   for maximum detection

% NOTES: 
% - the new detrending makes spike detection a simple function of setting the threshold to some fraction
%   of the standard deviation, and will mostly catch all activity above that reliably
% - it eliminates almost all background noise -- however, it does make it more difficult to find baseline activity
% - the width of the spikes should be preserved, again with cutoffs based on stddev fraction / other numerical value

function [spikecount] = maxID(time, fluo)
    fitstart = 1;
    fitend = 5000;  % defines the time range the polynomial is fitted on
    
    figure;     % initializes figure
    
    p1 = polyfit(time(fitstart:fitend), fluo(fitstart:fitend), 20);    % coefficient vector of degree 20 polynomial to part of the trace
    detrendfit = polyval(p1, time(fitstart:fitend));  % creates the polynomial
    
    % plot(time(fitstart:fitend), detrendfit);         % plots initial polynomial fit
    hold on;
    detrend = fluo(fitstart:fitend) - detrendfit;
    
    % better polyfit: plots a spline curve onto the noise, then subtracts the noise to leave spikes only 
    despiked = detrendfit;      % initialize the array that will eventually contain the noise, but not the spikes
    for i=1:fitend-fitstart-1   % cycle through the values in the 
        if detrend(i+1) < .5*std(detrend)        % CUTOFF: if the value is smaller than 0.5 stddev
            despiked(i+1) = fluo(i+fitstart);          % it's not a spike - keep it
        else
            despiked(i) = detrendfit(i);    % it is a spike - take the original polynomial fit
        end
    end
    
    spline = fit(time(fitstart:fitend), despiked, 'smoothingspline');   % now fit a spline curve to the despiked data
    plot(spline, time(fitstart:fitend), despiked);
    h = findobj(gca,'Type','line');   % use findobj to take raw graphics data from the spline curve
    
    for i=1:fitend-fitstart+1
       detrend2(i) = fluo(i+fitstart) - h(2).YData(i);   % subtract the spline data from the fluo curve
    end
    
    plot(time, fluo);     % plots original spike train
    plot(time(fitstart:fitend), detrend);  % plots spike train detrended with polynomial
    plot(time(fitstart:fitend), detrend2); % plots spike train detrended with spline
    
    % moving on to calculating maximum points
    detrend_deriv = diff(detrend2);
    detrend_spikeNumber = 0;
    
    i = 11;
    while i <= length(detrend_deriv)    % cycles through all the detrended values
        % identifies maxima above 1 stddev, ensures the fluorescence has been rising 
        if detrend2(i) > .75*std(detrend2) && detrend2(i)<detrend2(i-1) && detrend2(i-1)>detrend2(i-2) ...
                && detrend_deriv(i-2) > 0 && (detrend2(i-1)-detrend2(i-10))>std(detrend2)            
            % plot the maximum into the figure
            plot(time(fitstart:fitend), detrend2, time(fitstart-1 + i-1), detrend2(i-1), 'o');
            detrend_spikeNumber = detrend_spikeNumber + 1;
            i = i+10;   % ensures that a secondary peak within a single spike isn't overcounted
            hold on;            
        end
        i = i+1;
    end
    
    frequency = detrend_spikeNumber / (time(fitend) - time(fitstart));
    
    disp(['number of spikes counted: ' num2str(detrend_spikeNumber)]);
    disp(['spike frequency: ' num2str(frequency)]);
    
    ibi = zeros(1,detrend_spikeNumber);   % initialize vector of interburst intervals
    
    i = 11;
    j = 1;
    prev_spike = 1;
    while i <= length(detrend_deriv)    % cycles through all the detrended values
        % identifies maxima above 1 stddev, ensures the fluorescence has been rising 
        if detrend2(i) > .75*std(detrend2) && detrend2(i)<detrend2(i-1) && detrend2(i-1)>detrend2(i-2) ...
                && detrend_deriv(i-2) > 0 && (detrend2(i-1)-detrend2(i-10))>std(detrend2)
            % code to add the interburst interval to the IBI vector
            ibi(j) = (i-1) - prev_spike; 
            prev_spike = (i-1);
            j = j+1;
            i = i+10;
            hold on;            
        end
        i = i+1;
    end
    
    figure;             % plot the histogram of the interburst intervals
    histogram(ibi, 20); 
    
    spikecount = detrend_spikeNumber;
    
end

% spike conditions tested:
% - ensuring derivatives for i-2 && i-3 > 0 catches 69 (most), skips a few that have a smaller initial peak, and 
%   some smaller, denser peaks near the end
% - (detrend(i-1)-detrend(i-10))>std(detrend) hits 65, takes care of some of the double counts, still misses end
% - current version that captures all spikes in 7-26-noVnoS:
%       if detrend(i) > .75*std(detrend) && detrend(i)<detrend(i-1) && detrend(i-1)>detrend(i-2) ...
%               && detrend_deriv(i-2) > 0 && (detrend(i-1)-detrend(i-10))>std(detrend)
