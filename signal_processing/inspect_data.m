%% instantiate the library
disp('Loading the library...');
lib = lsl_loadlib();

% resolve a stream...
disp('Resolving an EEG stream...');
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'type','EEG'); end

% create a new inlet
disp('Opening an inlet...');
inlet = lsl_inlet(result{1});

data = zeros(64,250);

disp('Now receiving data...');
frame = 0;
while true
    % get data from the inlet
    [vec,ts] = inlet.pull_sample();

    data(:,end) = vec;
    data(:,1:end-1) = data(:,2:end);

    if frame == 25
        frame = 0;

%         mean(data(27,:),2)
        plot(data(1,:))
        pause(.001)
    end

    frame = frame + 1;

    % and display it
%     fprintf('%.2f\t',vec);
%     fprintf('%.5f\n',ts);
end