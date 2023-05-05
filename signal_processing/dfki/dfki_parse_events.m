function [parsed_events] = dfki_parse_events(eeglab_event_struct)
%DFKI_PARSE_EVENTS Summary of this function goes here
%   Detailed explanation goes here

    events_of_int = {'eventName', 'perceptualThreshold', 'TrialValue'};

    for i = 1:size(eeglab_event_struct,2)
    
        for ev = events_of_int
            ev = ev{1};
    
            start_ix = strfind(eeglab_event_struct(i).type, ev) + strlength(ev);
    
            switch ev
                case 'eventName'
                    
                    end_ev_name = strfind(eeglab_event_struct(i).type, '_');
    
                    parsed_events(i).(ev) = eeglab_event_struct(i).type(start_ix+1 : end_ev_name-1);
    
                case 'perceptualThreshold'
    
                    end_pT = min(strfind(eeglab_event_struct(i).type(start_ix:end), ';'));
    
                    parsed_events(i).(ev) = eeglab_event_struct(i).type(start_ix+1 : start_ix+end_pT-2);
    
                case 'TrialValue'
    
                    end_TV = strfind(eeglab_event_struct(i).type, 'TrialCondition');
    
                    parsed_events(i).(ev) = eeglab_event_struct(i).type(start_ix : end_TV-1);
            end
        end

        parsed_events(i).type = eeglab_event_struct(i).type;
        parsed_events(i).latency = eeglab_event_struct(i).latency;
        parsed_events(i).duration = eeglab_event_struct(i).duration;
    end
end

