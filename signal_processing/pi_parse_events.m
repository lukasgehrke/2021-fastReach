function [eeglab_struct] = pi_parse_events(eeglab_struct)
% CPS_PARSE_EVENTS parses a matlab struct by splitting key:value pairs
% seprated by ';'. If no separator is found in the event, leave it as is
    
    for i = 1:numel(eeglab_struct.event)    
        current_event = cellstr(strsplit(eeglab_struct.event(i).type, ';'));

        if length(current_event) > 1
            for j=1:length(current_event)
                key_val = cellstr(strsplit(current_event{j}, ':'));
                eeglab_struct.event(i).(key_val{1}) = key_val{2};
                if j==1
                    eeglab_struct.event(i).value = strcat(key_val{1}, ':', key_val{2});
                end
            end
        % else
            % pass
        end
    end
end

