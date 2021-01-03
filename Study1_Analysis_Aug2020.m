% Study 1 Analysis Script

% Selective attention to real-world objects drives their emotional appraisal
% Nathan J. Wispinski, Shihao Lin, James T. Enns, & Craig S. Chapman
% Attention, Perception, & Psychophysics (2020)

% Nathan Wispinski - Last updated Oct 30, 2020

clear all; close all; clc;
rng('shuffle');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Setup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Specify directory with scripts and data files for this project
homeDir = pwd; % Home
addpath(homeDir)

dataDir = [homeDir '\Data']; % Folder with all participant data .mat files
cd(dataDir);
subFolders = dir('OD*'); % Identify Study 1 Files
subOrder = {};

% Initialize some variables
group{1} = [];
group{2} = [];

groupFDA.x = [];
groupFDA.y = [];
groupFDA.z = [];
groupFDA.velX = [];
groupFDA.velY = [];
groupFDA.velZ = [];

groupMatDataRaw = [];

rxnTime = [];
mvmtTime = [];
startSide = [];
reachSide = [];
evalSide = [];
evalType = [];
evalTime = [];
evalXPos = [];
trialsOut = [];
blockOut = [];

badSubCtr = [];
goodSubCtr = 0;

badRecordCnt = 0;
badRecordCnt2 = 0;
tooEarlyMTPCnt = 0;
timeOutMTPCnt = 0;
missMTPCnt = 0;
tooSlowMTPCnt = 0;
goodMTPCnt = 0;
stdSlowCnt = 0;
stdSlowCnt2 = 0;

pAge = [];
pSex = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Read each participant's .mat data files into MATLAB and organize
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for sub = 1:length(subFolders)
    
    disp(subFolders(sub).name);
    subOrder{sub} = subFolders(sub).name;
    load(subFolders(sub).name); % Load in data_struct for this subject
    
    % Save demographic info
    pSex{sub} = data_struct.participant_info.gender;
    pAge(sub) = str2num(data_struct.participant_info.age);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Data Exclusions
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    trials = data_struct.matData.trial; % Trial # for this participant
    totalTrials(sub) = length(trials); % Count of trials completed pre- data screening
    
    % Remove NaN trials (bad from motion tracking recording)
    badRecordIdx = find(isnan(data_struct.newFda.x(:,1)));
    badRecordCnt(sub) = length(badRecordIdx);
    data_struct = removeTrials(data_struct,badRecordIdx);
    trials(badRecordIdx) = [];
    
    % Remove and count error trials (tooEarly=1, TimeOut=2, Miss=4)
    tooEarlyMTP = find(data_struct.matData.error(:,1)'); % Movement initiated before go cue
    timeOutMTP = find(data_struct.matData.error(:,2)'); % Reaction time was > 2 seconds
    missMTP = find(data_struct.matData.error(:,4)'); % Participant grabbed wrong object
    tooSlowMTP = find(data_struct.matData.error(:,3)'); % Movement time was > 2 seconds
    goodMTP = find(~any(data_struct.matData.error,2)');
    
    tooEarlyMTPCnt(sub) = length(tooEarlyMTP);
    timeOutMTPCnt(sub) = length(timeOutMTP);
    missMTPCnt(sub) = length(missMTP);
    tooSlowMTPCnt(sub) = length(tooSlowMTP);
    goodMTPCnt(sub) = length(goodMTP);
    
    data_struct = removeTrials(data_struct, unique([tooEarlyMTP timeOutMTP missMTP tooSlowMTP]));
    trials(unique([tooEarlyMTP timeOutMTP missMTP tooSlowMTP])) = [];
    
    % Remove the first block (practice)
    blk1 = find(data_struct.matData.block == 1);
    data_struct = removeTrials(data_struct, unique([blk1]));
    trials(unique([blk1])) = [];
    
    % Remove trials with bad evaluation (-1) or evaluation times > 15 seconds
    badRecordIdx2 = find(data_struct.matData.evalXPos<0 | data_struct.matData.evalTime>15);
    badRecordCnt2(sub) = length(badRecordIdx2);
    data_struct = removeTrials(data_struct,badRecordIdx2);
    trials(badRecordIdx2) = [];
    
    % Remove the slow MVMT TIME trials ( >2 standard deviations above participant's own mean)
    slowTrials = find(data_struct.matData.mvmtTime > mean(data_struct.matData.mvmtTime) + 2*std(data_struct.matData.mvmtTime));    
    stdSlowCnt(sub) = length(slowTrials);
    
    % Remove the slow RXN TIME trials ( >2 standard deviations above participant's own mean)
    slowTrials2 = find(data_struct.matData.rxnTime > mean(data_struct.matData.rxnTime) + 2*std(data_struct.matData.rxnTime));    
    stdSlowCnt2(sub) = length(slowTrials2);
    
    curSlowRemove = unique([slowTrials slowTrials2]);
    data_struct = removeTrials(data_struct, curSlowRemove);
    trials(curSlowRemove) = [];

    % Remove participants if less than 50% of 288 experimental trials pass the above criteria
        badSub = 0;
    if length(trials) < 144 % .50 of 288 non-practice reaches
        badSub = 1;
        badSubCtr = [badSubCtr [sub;-2;length(trials)]];
        subFolders(sub).name;
    else
        
    % Remove participants if less than 50% of trials in any of the 16 unique conditions (18 trials per 16 conditions = 288)
        for stSide = 1:2
            for enSide = 1:2
                for evSide = 1:2
                    for evType = 1:2
                        numIdx = find(data_struct.matData.startSide == stSide & data_struct.matData.reachSide == enSide ...
                            & data_struct.matData.evalSide == evSide & data_struct.matData.evalType == evType);
                        if length(numIdx) < 9 % Of 18 trials per condition
                            badSub = 1;
                            badSubCtr = [badSubCtr [sub;-1;length(numIdx)]];
                        end
                    end
                end
            end           
        end
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Extract this participant's cleaned data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Arrange participant's data_struct into data matrix "groupMatDataRaw"
        % Each row is a trial
        % Columns are:
        % (1) Subject Number
        % (2) Block Number
        % (3) Trial Number
        % (4) Trial Type (of 96 possible unique conditions (see runObsDeval)
        % (5) Start Side (Hand started left (1), or right (2) side of table)
        % (6) Reach Side (Cued to reach to left (1), or right (2) iPod)
        % (7) Evaluation Side (To-be-evaluated stimulus was presented on left (1), or right (2) iPod)
        % (8) Evaluation Type (To-be-evaluated stim was old (1) [on the iPod during the reach], or new (2) [not on the iPod during reach] )
        % (9) Image Type on the left (1 = Circle, 2 = Square, 3 = Polygon)
        % (10) Image type on the right (1 = Circle, 2 = Square, 3 = Polygon)
        % (11) Reach reaction time (Latency (seconds) from go beep to movement onset)
        % (12) Reach movement time (Latency (seconds) from movement onset to movement completion)
        % (13) Evaluation time (Latency (seconds) from evaluation stim presentation to evaluation confirmation)
        % (14) Affective evaluation (Rating from 0(- 'Least Cheery') to 400 (+ 'Most Cheery')
    
    if ~badSub
        
        groupMatDataRaw = [groupMatDataRaw; ...
        ones(length(trials),1)*sub data_struct.matData.block' data_struct.matData.trial' data_struct.matData.trialType' ...
        data_struct.matData.startSide' data_struct.matData.reachSide' data_struct.matData.evalSide' data_struct.matData.evalType' ...
        data_struct.matData.curImageL' data_struct.matData.curImageR' ...
        data_struct.matData.rxnTime' data_struct.matData.mvmtTime' data_struct.matData.evalTime' data_struct.matData.evalXPos'];
    
        goodSubCtr = goodSubCtr+1;
           
        groupFDA.x = [groupFDA.x; data_struct.newFda.x];
        groupFDA.y = [groupFDA.y; data_struct.newFda.y];
        groupFDA.z = [groupFDA.z; data_struct.newFda.z];
        groupFDA.velX = [groupFDA.velX; data_struct.newFda.velX];
        groupFDA.velY = [groupFDA.velY; data_struct.newFda.velY];
        groupFDA.velZ = [groupFDA.velZ; data_struct.newFda.velZ];
        group{1} = [group{1} data_struct.matData.trialType];
        group{2} = [group{2} ones(1,length(trials))*sub];
        
        trialsOut = [trialsOut trials-10]; % -10 Corrects for number of practice trials
        blockOut = [blockOut data_struct.matData.block];
        rxnTime = [rxnTime data_struct.matData.rxnTime];
        mvmtTime = [mvmtTime data_struct.matData.mvmtTime];
        startSide = [startSide data_struct.matData.startSide];
        reachSide = [reachSide data_struct.matData.reachSide];
        evalSide = [evalSide data_struct.matData.evalSide];
        evalType = [evalType data_struct.matData.evalType];
        evalTime = [evalTime data_struct.matData.evalTime];
        evalXPos = [evalXPos data_struct.matData.evalXPos];
    end

    % Clear data and move on to next participant's data
    clear data_struct;    
end
cd(homeDir); % Go back to home directory to save figure files, etc.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% ID Critical Conditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Sort data into 16 full conditions
% (2x2x2x2) (StartSide Right/Left * ReachSide Right/Left * EvalSide Right/Left * Old/New Evaluation image)

    % Naming scheme: 'L' or 'R' means start side,
    % Target/Distractor/Obstacle means where you're evaluating the stim
    % 'D' or 'O' means Target paired with a Distractor or Obstacle (i.e., did you have to reach around something on that trial?)
    % 'Old' or 'New' means you're evaluating novel stim, or what you saw on the past trial (associated with Target/Distractor/Obstacle)

% Left Side Start
LTargetDOld = find(startSide==1 & reachSide==1 & evalSide == 1 & evalType == 1);
LTargetDNew = find(startSide==1 & reachSide==1 & evalSide == 1 & evalType == 2);
LDistractorOld = find(startSide==1 & reachSide==1 & evalSide == 2 & evalType == 1);
LDistractorNew = find(startSide==1 & reachSide==1 & evalSide == 2 & evalType == 2);
LObstacleOld = find(startSide==1 & reachSide==2 & evalSide == 1 & evalType == 1);
LObstacleNew = find(startSide==1 & reachSide==2 & evalSide == 1 & evalType == 2);
LTargetOOld = find(startSide==1 & reachSide==2 & evalSide == 2 & evalType == 1);
LTargetONew = find(startSide==1 & reachSide==2 & evalSide == 2 & evalType == 2);
% Right Side Start
RTargetOOld = find(startSide==2 & reachSide==1 & evalSide == 1 & evalType == 1);
RTargetONew = find(startSide==2 & reachSide==1 & evalSide == 1 & evalType == 2);
RObstacleOld = find(startSide==2 & reachSide==1 & evalSide == 2 & evalType == 1);
RObstacleNew = find(startSide==2 & reachSide==1 & evalSide == 2 & evalType == 2);
RDistractorOld = find(startSide==2 & reachSide==2 & evalSide == 1 & evalType == 1);
RDistractorNew = find(startSide==2 & reachSide==2 & evalSide == 1 & evalType == 2);
RTargetDOld = find(startSide==2 & reachSide==2 & evalSide == 2 & evalType == 1);
RTargetDNew = find(startSide==2 & reachSide==2 & evalSide == 2 & evalType == 2);

% Critical Conditions by Old vs New
TargetOld = sort([LTargetDOld LTargetOOld RTargetOOld RTargetDOld]);
DistractorOld = sort([LDistractorOld RDistractorOld]);
ObstacleOld = sort([LObstacleOld RObstacleOld]);

TargetNew = sort([LTargetDNew LTargetONew RTargetONew RTargetDNew]);
DistractorNew = sort([LDistractorNew RDistractorNew]);
ObstacleNew = sort([LObstacleNew RObstacleNew]);

% Sort data into 4 critical conditions
Target = sort([LTargetDOld LTargetOOld RTargetOOld RTargetDOld]);
Distractor = sort([LDistractorOld RDistractorOld]);
Obstacle = sort([LObstacleOld RObstacleOld]);
Novel = sort([LTargetDNew LTargetONew RTargetONew RTargetDNew LDistractorNew RDistractorNew LObstacleNew RObstacleNew]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Ratings Figure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Rating by attentional condition

subID = unique(groupMatDataRaw(:,1)); % Numbers associated with subjects in GroupMatDataRaw

% For each participant, extract mean affective rating for each of the 4 critical conditions
for sub = 1:length( unique(groupMatDataRaw(:,1)) )
    idxTarget = intersect( find( groupMatDataRaw(:,1) == subID(sub)  ), Target );
    idxNovel = intersect( find( groupMatDataRaw(:,1) == subID(sub)  ), Novel );
    idxDistractor = intersect( find( groupMatDataRaw(:,1) == subID(sub)  ), Distractor );
    idxObstacle = intersect( find( groupMatDataRaw(:,1) == subID(sub)  ), Obstacle );
    
    evalTarget(sub) = mean( evalXPos(idxTarget) );
    evalNovel(sub) = mean( evalXPos(idxNovel) );
    evalDistractor(sub) = mean( evalXPos(idxDistractor) );
    evalObstacle(sub) = mean( evalXPos(idxObstacle) );
end

% Normalize data to calculate within-subjects error bars
    normMeans = [];
for sub = 1:length( unique(groupMatDataRaw(:,1)) )
    % Cousineau (2005) method based on Loftus and Masson (1994)
        % Normalized condition mean = condition mean - subject average + grand average
    subMean = mean([evalTarget(sub) evalDistractor(sub) evalObstacle(sub) evalNovel(sub)]);
    grandMean = mean(mean([evalTarget; evalDistractor; evalObstacle; evalNovel]));
    normMeans(sub,:) = [evalTarget(sub) evalDistractor(sub) evalObstacle(sub) evalNovel(sub)] - subMean + grandMean;
end
    % Morey (2008) correction
        % Multiply sample variances by (M/(M-1)), where M is # of conditions
normVar = var(normMeans) * (4/(4-1));
normSE = sqrt(normVar) / sqrt(size(normMeans,1)); % Standard error
normCI = 1.96 * normSE; % Size of 95% CI for corrected within-subjects standard error


%%%% Plot Ratings by Condition (Target, Novel, Distractor, Obstacle)
maxRating = 400; % Maximum rating in pixels (evalXPos is recorded on a 1-400 pixel line)
figure; hold on;
    % Plot 3 attentional condition means
b = bar([nanmean(evalTarget) nanmean(evalDistractor) nanmean(evalObstacle)]);
b.FaceColor = 'flat';
b.CData(1,:) = [.7 .2 .2]; % Target color
b.CData(2,:) = [.2 .2 .7]; % Distractor color
b.CData(3,:) = [.2 .7 .2]; % Obstacle color
    % Plot novel control condition
p = patch('vertices', [0.5, nanmean(evalNovel)-normCI(4); 0.5, nanmean(evalNovel)+normCI(4); 3.5, ...
    nanmean(evalNovel)+normCI(4); 3.5 nanmean(evalNovel)-normCI(4)], ...
          'faces', [1, 2, 3, 4], ...
          'FaceColor', 'k', ... % Novel color
          'EdgeColor', 'none', ...
          'FaceAlpha', 0.2);
plot([.5 3.5],[nanmean(evalNovel) nanmean(evalNovel)],'k');
    % Plot "Novel" text label
text(3.6,nanmean(evalNovel),'Novel','Rotation',90,'FontSize',12,'HorizontalAlignment','center');
    % Plot error bars
plot([1 1],[nanmean(evalTarget)-normCI(1) nanmean(evalTarget)+normCI(1)],'k');
plot([2 2],[nanmean(evalDistractor)-normCI(2) nanmean(evalDistractor)+normCI(2)],'k');
plot([3 3],[nanmean(evalObstacle)-normCI(3) nanmean(evalObstacle)+normCI(3)],'k');
    % Plotting options
ylim([(maxRating*.47) (maxRating*.57)]); xlim([.5 3.5]);
yticks(linspace((maxRating*.47),(maxRating*.57),11)); set(gca,'YTickLabel',[0 linspace(48,56,9) 100]);
xticks([1 2 3]); set(gca,'XTickLabel',{'Target', 'Distractor', 'Obstacle'});
set(gca,'TickDir','out');
y = ylabel('Average Rating (%)');
axis square;
set(gca,'FontSize',12);
set(gcf,'color','w');
set(y, 'Units', 'Normalized', 'Position', [-0.15, 0.5, 0]);
% saveas(gcf,'Study1_Reaching','pdf'); % Save figure in .pdf file format


% Repeated-measures ANOVA on attentional condition
varNames = {'Target','Distractor','Obstacle','Novel'};
t = array2table([evalTarget' evalDistractor' evalObstacle' evalNovel'],'VariableNames',varNames);
factorNames = {'Condition'};
within = table(varNames','VariableNames',factorNames);
rm = fitrm(t,'Target-Novel~1','WithinDesign',within);
ranovatbl = ranova(rm, 'WithinModel','Condition');
disp(ranovatbl);
% To get Greenhouse-Giesser epsilon, put breakpoint in line 1992 of RepeatedMeasuresModel.m

% Partial eta-squared effect size
SSError = ranovatbl.SumSq(2);
SSCondition = ranovatbl.SumSq(3);
n2partial = SSCondition / (SSError + SSCondition);

% two-tailed t-tests (bonferroni-corrected p-values)
% Multiple comparisons of conditions against novel baseline
bonferroniCorrection = .05 / 6;
[H,P,CI,STATS] = ttest(evalTarget,evalNovel); disp(P); disp(P < bonferroniCorrection);
[H,P,CI,STATS] = ttest(evalDistractor,evalNovel); disp(P); disp(P < bonferroniCorrection);
[H,P,CI,STATS] = ttest(evalObstacle,evalNovel); disp(P); disp(P < bonferroniCorrection);

% Calculate Cohen's d for target appreciation (technically Cohen's dav - see Cumming (2012))
cohensDav = (mean(evalTarget) - mean(evalNovel)) / ...
    ((std(evalTarget) + std(evalNovel)) / 2);





