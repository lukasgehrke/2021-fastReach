%%

s = load_xdf('/Users/lukasgehrke/Documents/publications/2021-fastReach/data/study/source/13/13_running_long.xdf');

s = load_xdf('/Users/lukasgehrke/Desktop/exp001/block_Default.xdf');

%%


figure; plot(s{1}.time_series(2,:)); hold on; plot(s{1}.time_series(3,:))
figure; plot(s{3}.time_series(2,:)); hold on; plot(s{3}.time_series(3,:))

vel = sqrt(diff(s{4}.time_series(4,:)).^2 + ...
    diff(s{4}.time_series(5,:)).^2 + ...
    diff(s{4}.time_series(6,:)).^2);

vel = vel / max(vel);

figure; plot(vel); hold on; plot(s{3}.time_series(2,:))