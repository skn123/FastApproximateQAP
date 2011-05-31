%% simulate independent edge models and classify using or not using the vertex names
clear; clc

n_MC= 1000;                           % # of samples
n   = 10;                           % # of vertices
alg.model = 'bern';

alg.fname   = 'poiss';    % different names will generate different simulations
switch alg.fname                    % choose simulation parameters
    case 'homo_kidney_egg'
        
        p   = 0.5;      % prob of connection for kidney
        q0  = 0.2;      % prob of connection for egg
        q1  = 0.8;      % prob of connection for egg
        egg = 1:5;      % vertices in egg
        
        E0=p*ones(n);   % params in class 0
        E0(egg,egg)=q0; % egg params in class 0
        
        E1=p*ones(n);   % params in class 1
        E1(egg,egg)=q1; % egg params in class 1
        
        P.n=n; P.p=p; P.q0=q0; P.q1=q1; P.egg=egg; P.S=n_MC; P.E0=E0; P.E1=E1;
        
    case 'hetero'
        
        E0=rand(n)*0.5+0.2;     % params in class 0
        E1=rand(n)*0.5;     % params in class 1
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        
    case 'structured'
        
        E0=0.1*ones(n);     % params in class 0
        E1=0.1*ones(n);     % params in class 1
        E0ind=[2 n+4 2*n+8 3*n+3 4*n+9 5*n+6 6*n+7 7*n+1 8*n+4 9*n+5];
        E1ind=[4 n+2 2*n+3 3*n+8 4*n+9 5*n+1 6*n+5 7*n+1 8*n+5 9*n+4];
        pp=randperm(n^2); pp=pp(1:10);
        E0([pp E0ind])=0.8;
        E1([pp E1ind])=0.8;
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        
    case 'hetero_kidney_egg'
        
        E0=rand(n);     % params in class 0
        E1=rand(n);     % params in class 1
        egg = 1:5;      % vertices in egg
        E1(egg,egg)=E0(egg,egg);
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        
    case 'hard_hetero'
        
        E0=rand(n);         % params in class 0
        E1=E0+randn(n)*.1;  % params in class 1
        E1(E1>=1)=1-1e-3;   % don't let prob be >1
        E1(E1<=0)=1e-3;     % or <0
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        
    case 'celegans'
        
        load('~/Research/data/EM/c_elegans/c_elegans_chemical_connectome.mat')
        
        n=279;
        m=10;
        thesem = [69,80,82,94,110,127,129,133,134,138];
        eps = 0.05;  % noise parameter "eps"
        sig = 15;     % egg parameter "sig"
        
        E0=A+eps;
        E1=E0;
        egg = sig*rand(m)-sig/2;
        E1(thesem,thesem) = E1(thesem,thesem) + egg;
        E1(E1<0)=eps;
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        alg.model='poiss';
        
    case 'poiss'
        
        E0=rand(n)*100;     % params in class 0
        E1=rand(n)*100;     % params in class 1
        
        P.n=n; P.S=n_MC; P.E0=E0; P.E1=E1;
        alg.model='poiss';
        
end

alg.datadir = '../../data/';
alg.figdir  = '../../figs/';

alg.save    = 1;                    % whether to save/print results
alg.names   = [{'LAP'}; {'QAP'}];   % which algorithms to run
alg.truth_start = false;            % start QAP at truth

alg.QAP_max_iters   = 10;           % max # of iterations when using QAP
alg.QAP_init        = eye(n);       % starting value for QAP


% # samples for testing and training
S0 = n_MC; % # of samples in class 0
S1 = n_MC; % # of samples in class 1

ytst=round(rand(n_MC,1));                   % sample classes iid where P[Y=1]=1/2

ytst1=find(ytst==1);
len1=sum(ytst);

ytst0=find(ytst==0);
len0=n_MC-len1;

% sample data
if strcmp(alg.model,'bern')
    A0 = repmat(E0,[1 1 S0]) > rand(n,n,S0);    % class 0 samples
    A1 = repmat(E1,[1 1 S1]) > rand(n,n,S1);    % class 1 samples
    Atst=nan(n,n,n_MC);
    Atst(:,:,ytst1)=repmat(E1,[1 1 len1]) > rand(n,n,len1);    % class 0 samples
    Atst(:,:,ytst0)=repmat(E0,[1 1 len0]) > rand(n,n,len0);    % class 0 samples
elseif strcmp(alg.model,'poiss')
    A0 = poissrnd(repmat(E0,[1 1 S0]));    % class 0 samples
    A1 = poissrnd(repmat(E1,[1 1 S1]));    % class 1 samples
    Atst=nan(n,n,n_MC);
    Atst(:,:,ytst0)=poissrnd(repmat(E0,[1 1 len0]));    % class 0 samples
    Atst(:,:,ytst1)=poissrnd(repmat(E1,[1 1 len1]));    % class 0 samples
end
Atrn = cat(3,A0,A1);                        % concatenate to get all training samples


% parameters for naive bayes classifiers
P.lnE0  = log(P.E0);
P.ln1E0 = log(1-P.E0);
P.lnE1  = log(P.E1);
P.ln1E1 = log(1-P.E1);

P.lnprior0 = log(S0/n_MC);
P.lnprior1 = log(S1/n_MC);

if alg.save
    save([alg.datadir alg.fname])
end


%% unlabel and don't try to do any assignment; this gives us L_chance

% make data unlabeled
adj_mat=0*Atst;
for i=n_MC
    q=randperm(n);
    A=Atst(:,:,i);
    adj_mat(:,:,i)=A(q,q);
end

% naive bayes classify
Lhat = naive_bayes_classify(adj_mat,ytst,P);
Lhats.rand  = Lhat.all;
Lsems.rand  = sqrt(Lhat.all*(1-Lhat.all))/sqrt(n_MC);

%% performance using true parameters and labels; this gives us L_*

Lhat = naive_bayes_classify(Atst,ytst,P);
Lhats.star  = Lhat.all;
Lsems.star  = sqrt(Lhat.all*(1-Lhat.all))/sqrt(n_MC);

%% test classifier using only 2 unlabeled training samples

alg.classifier = 'BPI'; % could be BPI=bayes plugin or 1NN
alg.QAP_max_iters=10;  % meaning don't do line search in QAP

[LAP QAP] = classify_unlabeled_graphs(Atrn,Atst,ytst,P,alg);

Lhats.LAP=LAP.Lhat;
Lsems.LAP=LAP.Lsem;

Lhats.QAP=QAP.Lhat;
Lsems.QAP=QAP.Lsem;

if alg.save
    save([alg.datadir alg.fname '_results'])
end

%% plot model

figure(2), clf
fs=10;  % fontsize

emax=max(max([P.E0(:) P.E1(:) abs(P.E0(:)-P.E1(:))]));

% class 0
subplot(131)
image(60*P.E0/emax)
colormap('gray')
title('class 0 mean','fontsize',fs)
xlabel('vertices','fontsize',fs)
ylabel('vertices','fontsize',fs)
set(gca,'fontsize',fs,'DataAspectRatio',[1 1 1])

% class 1
subplot(132)
image(60*P.E1/emax)
title('class 1 mean','fontsize',fs)
set(gca,'fontsize',fs)
set(gca,'fontsize',fs,'DataAspectRatio',[1 1 1])

% difference
subplot(133)
image(60*abs(P.E0-P.E1)/emax)
colormap('gray')
title('difference','fontsize',fs)
set(gca,'fontsize',fs)
set(gca,'fontsize',fs,'DataAspectRatio',[1 1 1])
colorbar('Position',[.925 .3 .02 .4],'YTick',[0 15 30 45 60],'YTickLabel',[0 25 50 75 100],'fontsize',fs)


if alg.save
    wh=[6 2];   %width and height
    set(gcf,'PaperSize',wh,'PaperPosition',[0 0 wh],'Color','w');
    figname=[alg.figdir alg.fname '_model'];
    print('-dpdf',figname)
    %     print('-deps',figname)
    %     saveas(gcf,figname)
end

%% plot Lhat and obj error together

fig=figure(6); clf, hold all
gray=0.5*[1 1 1];
gray2=0.25*[1 1 1];
fs=18;
ms=16;

X=0:QAP.max_iters;
Y1=[Lhats.rand Lhats.QAP];
Y2=QAP.obj_avg;
[AX,H1,H2] = plotyy(X, Y1, X, Y2);
xlabel('iteration #','fontsize',fs)
title('QAP Performance Statistics','fontsize',fs)

% y1 stuff
set(get(AX(1),'Ylabel'),'String','Misclassification rate','color','k','fontsize',fs)
set(AX(1),'YColor','k','YLim',[0 0.5],'YTick',[0 0.25 0.5],'fontsize',fs)
set(fig, 'CurrentAxes', AX(1));
hold on;
h(1)=errorbar(0:QAP.max_iters,[Lhats.rand Lhats.QAP],[Lsems.rand Lsems.QAP]);
set(h(1),'linewidth',2,'Marker','.','Markersize',ms,'Color','k')
text(0.2,0.46,'L_c_h_a_n_c_e','fontsize',fs)

errorbar(1.1,Lhats.LAP,Lsems.LAP,'color',gray2,'linewidth',2,'Marker','.','Markersize',ms)
text(1.2,Lhats.LAP*1.1,'L_L_A_P','fontsize',fs,'color',gray2)
text(2.1,Lhats.QAP(2)*1.1,'L_Q_A_P','fontsize',fs,'color','k')

% text(9.5,Lhats.star+.05,'L_*','fontsize',fs)
% errorbar(QAP.max_iters,Lhats.star,Lsems.star,'k','linewidth',2,'Marker','.','Markersize',ms)

% set y2 stuff
set(get(AX(2),'Ylabel'),'String','QAP objective function','color',gray,'fontsize',fs)
set(AX(2),'YColor',gray,'fontsize',fs)
set(fig, 'CurrentAxes', AX(2));
hold on;
h(2)=errorbar(0:QAP.max_iters,QAP.obj_avg,QAP.obj_sem);
set(h(2),'linewidth',2,'Marker','.','Markersize',ms,'Color',gray)
text(2.1,QAP.obj_avg(2)*1.5,'f_Q_A_P','fontsize',fs,'color',gray)


if alg.save
    set(gcf,'Color','w',...
        'PaperSize',[9 7]); %,...
    figname=[alg.figdir alg.fname '_performance'];
    print('-dpdf',figname)
    %     print('-deps',figname)
    %     saveas(gcf,figname)
end