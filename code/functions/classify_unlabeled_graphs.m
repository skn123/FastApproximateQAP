function [LAP QAP] = classify_unlabeled_graphs(Atrn,Atst,ytst,P,alg)
% this function classifies unlabeled graphs, in the following steps:
%
% (i) permute Atst to be like both a single Atrn in class 0 and a single
% Atrn in class 1
% (ii) compute the likelihood of the permuted Atsts coming from either of
% the classes
%
% we approximate solving the permuation by using LAP and/or QAP
% initial conditions can be set for both
% QAP is iterative, so we can set the number of iterations
%
% INPUT:
%   Atrn:   an n_V x n_V x S/2 array of adjacency matrices for training
%   Atst:   an n_V x n_V x S/2 array of adjacency matrices for testing
%   ytst:   list of classes for test data
%   P:      structure of parameters necessary for naive bayes classification
%   alg:    a structure of settings for the algorithms
%
% OUTPUT:
%   LAP:    a structure containing all the LAP results
%   QAP:    a structure containing all the QAP results

%% initialize stuff

siz = size(Atrn);
n_V   = siz(1);       % # of vertices
n_MC= length(ytst);   % total # of samples

if alg.truth_start == false     % if not starting at the truth, generate permuations for the test graphs
    tst_ind=zeros(n_MC,n_V);
    for j=1:n_MC
        tst_ind(j,:) = randperm(n_V);
    end
end

if strcmp(alg.names(1),'LAP'),
    LAP.time    = 0;
    LAP.do      = true;
    LAP.yhat    = NaN(n_MC,1);
    LAP.correct = NaN(n_MC,1);
    LAP.work0   = NaN(n_MC,1);
    LAP.work1   = NaN(n_MC,1);
    LAP.classifier = alg.classifier;
else LAP.do = false;
end

if strcmp(alg.names(2),'QAP'),
    QAP.time    = 0;
    QAP.do      = true;
    QAP.yhat    = NaN(n_MC,alg.QAP_max_iters);
    QAP.correct = NaN(n_MC,alg.QAP_max_iters);
    QAP.work0   = NaN(n_MC,alg.QAP_max_iters);
    QAP.work1   = NaN(n_MC,alg.QAP_max_iters);
    QAP.obj0    = NaN(n_MC,alg.QAP_max_iters);
    QAP.obj1    = NaN(n_MC,alg.QAP_max_iters);
    QAP.classifier = alg.classifier;
else QAP.do = false;
end

for j=1:n_MC
    
    if alg.truth_start == false
        A = Atst(tst_ind(j,:),tst_ind(j,:),j);
    else
        A = Atst(:,:,j);
    end
    
    % do LAP
    if LAP.do
        starttime = cputime;
        LAP_ind0 = munkres(-Atrn(:,:,j)*A');     %Note that sum(sum(-A(LAP,:).*Atst))==f
        LAP.work0(j)=norm(Atrn(:,:,j)-A(LAP_ind0,:)) <= norm(Atrn(:,:,j)-A); % check that LAP work
        
        LAP_ind1 = munkres(-Atrn(:,:,j+n_MC)*A');     %Note that sum(sum(-A(LAP,:).*A))==f
        LAP.work1(j)=norm(Atrn(:,:,j+n_MC)-A(LAP_ind1,:)) <= norm(Atrn(:,:,j+n_MC)-A); % check that LAP work
        
        if strcmp(LAP.classifier,'BPI')
            LAP_lik0=sum(sum(A(LAP_ind0,:).*P.lnE0+(1-A(LAP_ind0,:)).*P.ln1E0));
            LAP_lik1=sum(sum(A(LAP_ind1,:).*P.lnE1+(1-A(LAP_ind1,:)).*P.ln1E1));
            
        elseif strcmp(LAP.classifier,'1NN')
            LAP_lik0=-sum(sum(abs(A(LAP_ind0,:)-Atrn(:,:,j))));
            LAP_lik1=-sum(sum(abs(A(LAP_ind1,:)-Atrn(:,:,j+n_MC))));
        end
        [~, bar] = sort([LAP_lik0, LAP_lik1]);
        LAP.yhat(j)=bar(2)-1;
        LAP.correct(j)=(LAP.yhat(j)==ytst(j));
        LAP.time = LAP.time + cputime-starttime;
    end
    
    % do QAP
    if QAP.do
        
        starttime = cputime;
        [~,~,~,iter0,fs0,QAP_inds0]=sfw(Atrn(:,:,j),-A,alg.QAP_max_iters,alg.QAP_init);
        
        QAP.obj0(j,1) = sum(sum(Atrn(:,:,j).*A)); %
        for ii=1:iter0
            QAP.obj0(j,ii+1) = fs0(ii); %sum(sum(Atrn(:,:,j).*A(QAP_inds0{ii},QAP_inds0{ii}))); %norm(Atrn(:,:,j) - A(QAP_inds0{ii},QAP_inds0{ii}));
            QAP.work0(j,ii)= QAP.obj0(j,ii+1) <= QAP.obj0(j,1); % check that QAP works
        end
        
        [~,~,~,iter1,fs1,QAP_inds1]=sfw(Atrn(:,:,j+n_MC),-A,alg.QAP_max_iters,alg.QAP_init);
        QAP.obj1(j,1)  = sum(sum(Atrn(:,:,j+n_MC).*A)); %norm(Atrn(:,:,j+n_MC)-A);
        for ii=1:iter1
            QAP.obj1(j,ii+1) = fs1(ii); %sum(sum(Atrn(:,:,j+n_MC).*A(QAP_inds1{ii},QAP_inds1{ii}))); %norm(Atrn(:,:,j+n_MC) - A(QAP_inds1{ii},QAP_inds1{ii}));
            QAP.work1(j,ii)= QAP.obj1(j,ii+1) <= QAP.obj1(j,1); % check that QAP works
        end
        
        for ii=1:min(iter0,iter1)
            if strcmp(LAP.classifier,'BPI')
                QAP_lik0=sum(sum(A(QAP_inds0{ii},QAP_inds0{ii}).*P.lnE0+(1-A(QAP_inds0{ii},QAP_inds0{ii})).*P.ln1E0));
                QAP_lik1=sum(sum(A(QAP_inds1{ii},QAP_inds1{ii}).*P.lnE1+(1-A(QAP_inds1{ii},QAP_inds1{ii})).*P.ln1E1));
            elseif strcmp(LAP.classifier,'1NN')
                QAP_lik0=-sum(sum(abs(A(QAP_inds0{ii},QAP_inds0{ii})-Atrn(:,:,j))));
                QAP_lik1=-sum(sum(abs(A(QAP_inds1{ii},QAP_inds1{ii})-Atrn(:,:,j+n_MC))));
            end
            [~, bar] = sort([QAP_lik0, QAP_lik1]);
            QAP.yhat(j,ii)=bar(2)-1;
            QAP.correct(j,ii)=(QAP.yhat(j)==ytst(j));
        end
        QAP.time = QAP.time + cputime-starttime;
        
    end
end

if LAP.do
    LAP.Lhat = 1-mean(LAP.correct);
    LAP.Lstd = std(LAP.correct);
    LAP.Lvar = var(LAP.correct);
    LAP.Lsem = sqrt(LAP.Lhat*(1-LAP.Lhat))/sqrt(n_MC);
end

if QAP.do
    for ii=1:alg.QAP_max_iters+0.5;
        corrects = QAP.correct(:,ii);
        keeper   = ~isnan(corrects);
        corrects = corrects(keeper);
        
        QAP.Lhat(ii)= 1-mean(corrects);
        QAP.Lvar(ii)= var(corrects);
        QAP.Lstd(ii)= std(corrects);
        QAP.Lsem(ii)= sqrt(QAP.Lhat(ii)*(1-QAP.Lhat(ii)))/sqrt(n_MC);
        QAP.num(ii) = length(corrects);
        QAP.obj0_avg(ii+1) = mean(QAP.obj0(keeper,ii+1));
        QAP.obj1_avg(ii+1) = mean(QAP.obj1(keeper,ii+1));
        QAP.obj0_var(ii+1) = var(QAP.obj0(keeper,ii+1));
        QAP.obj1_var(ii+1) = var(QAP.obj1(keeper,ii+1));
    end
    QAP.obj0_avg(+1) = mean(QAP.obj0(:,+1));
    QAP.obj1_avg(+1) = mean(QAP.obj1(:,+1));
    QAP.obj0_var(+1) = var(QAP.obj0(:,+1));
    QAP.obj1_var(+1) = var(QAP.obj1(:,+1));
end