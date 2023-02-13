%%%%%%%%%%%%%%%%%%%%
% Forecasts_annual.m
%%%%%%%%%%%%%%%%%%%%

% Last modified: 07-02-2012

clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loading data and defining variables, 1926-2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Equity premium

market_return=xlsread('Returns_handbook_data','Annual',...
    'p57:p141'); % S&P 500 VW return
r_f_lag=xlsread('Returns_handbook_data','Annual',...
    'k56:k140'); % risk-free rate, lagged (1925-2009)
equity_premium=market_return-r_f_lag; % excess return

% Predictors

D=xlsread('Returns_handbook_data','Annual','c57:c141'); % dividends
SP500=xlsread('Returns_handbook_data','Annual',...
    'b57:b141'); % S&P 500 index
DP=log(D)-log(SP500); % log dividend-price ratio
SP500_lag=xlsread('Returns_handbook_data','Annual',...
    'b56:b140'); % S&P 500 index, lagged (1925-2009)
DY=log(D)-log(SP500_lag); % log dividend yield
E=xlsread('Returns_handbook_data','Annual','d57:d141'); % earnings
EP=log(E)-log(SP500); % log earnings-price ratio
DE=log(D)-log(E); % log dividend-payout ratio
SVAR=xlsread('Returns_handbook_data','Annual','o57:o141'); % volatility
BM=xlsread('Returns_handbook_data','Annual',...
    'e57:e141'); % book-to-market ratio
NTIS=xlsread('Returns_handbook_data','Annual',...
    'j57:j141'); % net equity issuing activity
TBL=xlsread('Returns_handbook_data','Annual',...
    'f57:f141'); % T-bill rate
LTY=xlsread('Returns_handbook_data','Annual',...
    'i57:i141'); % long-term government bond yield
LTR=xlsread('Returns_handbook_data','Annual',...
    'm57:m141'); % long-term government bond return
TMS=LTY-TBL; % term spread
AAA=xlsread('Returns_handbook_data','Annual',...
    'g57:g141'); % AAA-rated corporate bond yield
BAA=xlsread('Returns_handbook_data','Annual',...
    'h57:h141'); % BAA-rated corporate bond yield
DFY=BAA-AAA; % default yield spread
CORPR=xlsread('Returns_handbook_data','Annual',...
    'n57:n141'); % long-term corporate bond return
DFR=CORPR-LTR; % default return spread
INFL_lag=xlsread('Returns_handbook_data','Annual',...
    'l56:l140'); % inflation, lagged (1925-2009)
ECON=[DP DY EP DE SVAR BM NTIS TBL LTY LTR TMS DFY DFR INFL_lag];
ECON_sink=[DP DY EP SVAR BM NTIS TBL LTY LTR DFY DFR INFL_lag];

% Sum-of-the-parts variables

E_lag=xlsread('Returns_handbook_data','Annual',...
    'd56:d140'); % earnings, lagged (1925-2009)
E_growth=(E-E_lag)./E_lag; % earnings growth
DP_SOP=D./SP500; % D/P
r_f=xlsread('Returns_handbook_data','Annual',...
    'k57:k141'); % risk-free rate

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Estimating full-sample parameters for Campbell-Thompson restrictions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

beta_full=zeros(size(ECON,2),1);
T=size(equity_premium,1);
LHS=equity_premium(2:T);
for i=1:size(ECON,2);
    RHS_i=[ECON(1:T-1,i) ones(T-1,1)];
    results_i=ols(LHS,RHS_i);
    beta_full(i)=results_i.beta(1);
    disp(i); 
end;
beta_full(5)=1; % restricting SVAR slope coefficient to be positive

% NB: following Campbell and Thompson (2008) by using full-sample
% estimates as theoretical 'priors' (although we make sure that
% SVAR slope coefficient is positive)

%%%%%%%%%%%%%%%
% Preliminaries
%%%%%%%%%%%%%%%

Y=equity_premium;
T=size(Y,1);
N=size(ECON,2);
R=(1946-1926)+1; % in-sample period, 1926-1946
P_0=(1956-1946); % holdout out-of-sample period, 1947-1956
P=T-(R+P_0); % forecast evaluation period, 1957-2010
theta=0.75; % discound factor for DMSFE pooled forecast
r=1; % number of principal components
MA_SOP=20; % window size for SOP forecast

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Computing forecasts, 1947-2010 (includes holdout OOS period)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FC_HA=zeros(P_0+P,1);
FC_ECON=zeros(P_0+P,N);
beta_ECON=zeros(P_0+P,N,2);
FC_ECON_CT=zeros(P_0+P,N);
FC_OTHER=zeros(P_0+P,5+size(theta,1));
FC_OTHER_CT=zeros(P_0+P,5+size(theta,1));
for t=1:P_0+P;
    FC_HA(t)=mean(Y(1:R+(t-1)));

    % Individual predictive regression forecasts

    X_t=ECON(1:R+(t-1)-1,:);
    Y_t=Y(2:R+(t-1));
    for i=1:N;
        results_t_i=ols(Y_t,[X_t(:,i) ones(R+(t-1)-1,1)]);
        FC_ECON(t,i)=[ECON(R+(t-1),i) 1]*results_t_i.beta;
        beta_ECON(t,i,1)=results_t_i.beta(1);
        beta_ECON(t,i,2)=results_t_i.bstd(1);
        if beta_full(i)>0;
            if results_t_i.beta(1)>0;
                FC_ECON_CT(t,i)=FC_ECON(t,i);
            elseif results_t_i.beta(1)<0;
                FC_ECON_CT(t,i)=FC_HA(t);
            end;
        elseif beta_full(i)<0;
            if results_t_i.beta(1)<0;
                FC_ECON_CT(t,i)=FC_ECON(t,i);
            elseif results_t_i.beta(1)>0;
                FC_ECON_CT(t,i)=FC_HA(t);
            end;
        end;
        if FC_ECON_CT(t,i)<0;
            FC_ECON_CT(t,i)=0;
        end;
    end;
    if t>P_0;

        % Kitchen sink forecast

        X_t_sink=ECON_sink(1:R+(t-1)-1,:);
        results_t_sink=ols(Y_t,[X_t_sink ones(R+(t-1)-1,1)]);
        FC_OTHER(t,1)=[ECON_sink(R+(t-1),:) 1]*results_t_sink.beta;
        if FC_OTHER(t,1)<0;
            FC_OTHER_CT(t,1)=0;
        else
            FC_OTHER_CT(t,1)=FC_OTHER(t,1);
        end;

        % SIC forecast

        j_max=3; % consider models with up to 3 predictors to save time
        SIC_t=[];
        for j=1:j_max;
            select_j=nchoosek(1:1:size(X_t_sink,2),j);
            for k=1:size(select_j,1);
                X_t_j_k=[X_t_sink(1:R+(t-1)-1,select_j(k,:)) ...
                    ones(R+(t-1)-1,1)];
                results_t_j_k=ols(Y_t,X_t_j_k);
                SIC_t_j_k=log(results_t_j_k.resid'*results_t_j_k.resid/...
                    size(Y_t,1))+log(size(Y_t,1))*size(X_t_j_k,2)/...
                    size(Y_t,1);
                FC_t_j_k=[ECON_sink(R+(t-1),select_j(k,:)) 1]*...
                    results_t_j_k.beta;
                SIC_t=[SIC_t ; SIC_t_j_k FC_t_j_k];
            end;
        end;
        [SIC_t_min,SIC_t_min_index]=min(SIC_t(:,1));
        FC_OTHER(t,2)=SIC_t(SIC_t_min_index,2);
        if FC_OTHER(t,2)<0;
            FC_OTHER_CT(t,2)=0;
        else
            FC_OTHER_CT(t,2)=FC_OTHER(t,2);
        end;

        % Pooled forecast: simple average

        FC_OTHER(t,3)=mean(FC_ECON(t,:),2);
        if FC_OTHER(t,3)<0;
            FC_OTHER_CT(t,3)=0;
        else
            FC_OTHER_CT(t,3)=FC_OTHER(t,3);
        end;

        % Pooled forecast: DMSFE

        powers_t=(t-2:-1:0)';
        m=sum((kron(ones(1,N),(theta*ones(t-1,1)).^powers_t)).*...
            ((kron(ones(1,N),Y(R+1:R+(t-1)))-FC_ECON(1:(t-1),:)).^2))';
        omega=(m.^(-1))/(sum(m.^(-1)));
        FC_OTHER(t,4)=FC_ECON(t,:)*omega;
        if FC_OTHER(t,4)<0;
            FC_OTHER_CT(t,4)=0;
        else
            FC_OTHER_CT(t,4)=FC_OTHER(t,4);
        end;

        % Diffusion index forecast

        X_t_DI_standardize=zscore(ECON(1:R+(t-1),:));
        [Lambda_t F_t]=princomp(X_t_DI_standardize);
        results_t_DI=ols(Y_t,[F_t(1:end-1,1:r) ones(R+(t-1)-1,1)]);
        FC_OTHER(t,5)=[F_t(end,1:r) 1]*results_t_DI.beta;
        if FC_OTHER(t,5)<0;
            FC_OTHER_CT(t,5)=0;
        else
            FC_OTHER_CT(t,5)=FC_OTHER(t,5);
        end;

        % Sum-of-the-parts forecast

        FC_OTHER(t,6)=mean(E_growth(R+(t-1)-MA_SOP+1:R+(t-1)))+...
            DP_SOP(R+(t-1))-r_f(R+(t-1));
        if FC_OTHER(t,6)<0;
            FC_OTHER_CT(t,6)=0;
        else
            FC_OTHER_CT(t,6)=FC_OTHER(t,6);
        end;
    end;
    disp([t FC_HA(t) FC_OTHER(t,:)]); 
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Forecast evaluation based on asselt allocation exercise, 1957-2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

actual=Y(R+P_0+1:end);
FC_HA=FC_HA(P_0+1:end);
FC_ECON=FC_ECON(P_0+1:end,:);
FC_ECON_CT=FC_ECON_CT(P_0+1:end,:);
FC_OTHER=FC_OTHER(P_0+1:end,:);
FC_OTHER_CT=FC_OTHER_CT(P_0+1:end,:);
gamma_MV=5; % coefficient of relative risk aversion
window_VOL=5; % window size for estimating volatility
FC_VOL=zeros(P,1);
for t=1:P;
    FC_VOL(t)=mean(Y(R+P_0+(t-1)-window_VOL+1:R+P_0+(t-1)).^2)-...
        (mean(Y(R+P_0+(t-1)-window_VOL+1:R+P_0+(t-1))))^2;
end;
r_f_lag_P=r_f_lag(R+P_0+1:R+P_0+P);
[U_HA,w_HA]=Perform_asset_allocation(actual,r_f_lag_P,FC_HA,FC_VOL,...
    gamma_MV);
U_ECON=zeros(size(FC_ECON,2),1);
U_ECON_CT=zeros(size(FC_ECON_CT,2),1);
w_ECON=zeros(P,size(FC_ECON,2));
w_ECON_CT=zeros(P,size(FC_ECON_CT,2));
for i=1:size(U_ECON,1);
    [U_ECON(i,1),w_ECON(:,i)]=Perform_asset_allocation(actual,...
        r_f_lag_P,FC_ECON(:,i),FC_VOL,gamma_MV);
    [U_ECON_CT(i,1),w_ECON_CT(:,i)]=Perform_asset_allocation(actual,...
        r_f_lag_P,FC_ECON_CT(:,i),FC_VOL,gamma_MV);
end;
delta_ECON=100*(U_ECON-kron(U_HA',ones(size(FC_ECON,2),1)));
delta_ECON_CT=100*(U_ECON_CT-kron(U_HA',ones(size(FC_ECON_CT,2),1)));
U_OTHER=zeros(size(FC_OTHER,2),1);
U_OTHER_CT=zeros(size(FC_OTHER_CT,2),1);
w_OTHER=zeros(P,size(FC_OTHER,2));
w_OTHER_CT=zeros(P,size(FC_OTHER_CT,2));
for i=1:size(U_OTHER,1);
    [U_OTHER(i,1),w_OTHER(:,i)]=Perform_asset_allocation(actual,...
        r_f_lag_P,FC_OTHER(:,i),FC_VOL,gamma_MV);
    [U_OTHER_CT(i,1),w_OTHER_CT(:,i)]=Perform_asset_allocation(actual,...
        r_f_lag_P,FC_OTHER_CT(:,i),FC_VOL,gamma_MV);
end;
delta_OTHER=100*(U_OTHER-kron(U_HA',ones(size(FC_OTHER,2),1)));
delta_OTHER_CT=100*(U_OTHER_CT-kron(U_HA',ones(size(FC_OTHER_CT,2),1)));
%save('Forecasts_annual_store','actual','FC_HA','FC_ECON','beta_ECON',...
%    'FC_ECON_CT','FC_OTHER','FC_OTHER_CT','FC_VOL','w_HA','w_ECON',...
%    'w_ECON_CT','w_OTHER','w_OTHER_CT','delta_ECON','delta_ECON_CT',...
%    'delta_OTHER','delta_OTHER_CT');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Writing results to spreadsheet
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%xlswrite('Returns_handbook_results',delta_ECON(:,1),...
%    'Annual','d4');
%xlswrite('Returns_handbook_results',delta_OTHER(:,1),...
%    'Annual','d19');
%xlswrite('Returns_handbook_results',delta_ECON_CT(:,1),...
%    'Annual','h4');
%xlswrite('Returns_handbook_results',delta_OTHER_CT(:,1),...
%    'Annual','h19');
