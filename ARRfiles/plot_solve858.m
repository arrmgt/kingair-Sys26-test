ss = sprintf('%s (%i Hz)',X.RawFile,X.procRate);
tytle = strrep(ss,'_','\_');
    nn = 1;
    figure(nn)
        plot(PSA(kk),[(DP1(kk)+PSA0(kk)-PTB(kk)), (DP2(kk)+PSB0(kk)-PTB(kk))],'.')
        grid
        v = axis;
        v = [400 800 -10 30];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Static Pressure [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Pressure Differences [hPa]','FontSize',15,'Fontweight','bold')
        legend('DP1+PSA-PTB','DP2+PSB-PTB','location','northeast','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-PS-PTBs.png",nn);
        saveas(gcf,ss);

    nn = nn + 1;
    figure(nn)
        plot([1:numel(q0a)]'/X.procRate/60,[(DP1(kk)+PSA0(kk)-PTB(kk)), (DP2(kk)+PSB0(kk)-PTB(kk))])
        grid
        v = axis;
        v = [v(1) v(2) -10 30];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Time [min]','FontSize',15,'Fontweight','bold')
        ylabel('Pressure Differences [hPa]','FontSize',15,'Fontweight','bold')
        legend('DP1+PSA-PTB','DP2+PSB-PTB','location','northeast','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-PTBs.png",nn);
        saveas(gcf,ss);

    nn =nn + 1;
    figure(nn)
        plot(PSA(kk),[DP1(kk)+PSA0(kk)-DP2(kk)-PSB0(k)],'.')
        grid
        v = axis;
        v = [v(1) v(2) v(3) v(4)];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Static Pressure [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Pressure Differences [hPa]','FontSize',15,'Fontweight','bold')
        legend('DP1+PSA-DP2-PSB','location','northeast','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-PS,PTBs.png",nn);
        saveas(gcf,ss);

    nn = nn + 1;
    figure(nn)
        plot([1:numel(q0a)]'/X.procRate/60,[DP1(kk)+PSA(kk)-DP2(kk)-PSB(kk)])
        grid
        v = axis;
        v = [v(1) v(2) -0.5 1.5];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Time [min]','FontSize',15,'Fontweight','bold')
        ylabel('Pressure Differences [hPa]','FontSize',15,'Fontweight','bold')
        legend('DP1+PSA-DP2-PSB','location','northeast','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-DPs.png",nn);
        saveas(gcf,ss);

    nn = nn + 1;
    figure(nn)
        plot(CABINP(kk),[DP1(kk)+PSA(kk)-DP2(kk)-PSB(kk)],'.')
        grid
        v = axis;
        v = [v(1) v(2) -0.5 1.5];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('CABINP [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Pressure Differences [hPa]','FontSize',15,'Fontweight','bold')
        legend('DP1+PSA-DP2-PSB','location','northeast','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-CABINP-DPs.png",nn);
        saveas(gcf,ss);
        
    nn =nn+1;
    figure(nn)
        plot([1:numel(qx0)]'/X.procRate/60,[qx0,q0a],'.')
        grid
        v = axis;
        v = [v(1) v(2) 20 80];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (%s)',stats0a.dof,DP1str);
        text(0.25*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Time [min]','FontSize',15,'Fontweight','bold')
        ylabel('Q\_impact','FontSize',15,'Fontweight','bold')
        legend('Q\_old','Q\_new','northwest','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-Q-old-new-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot([1:numel(qx0)]'/X.procRate/60,[f0a,f0b],'.')
        grid
        v = axis;
        if contains(DP1str,'DP1')
            v = [v(1) v(2) 1.5 2];
        else
            v = [v(1) v(2) 1.7 2.2];
        end
        axis(v);
        v = axis;
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i  (%s)',stats0a.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        text(v(1)*1.05,v(3).*1.00,sprintf('Fig. %i',nn),'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('f-DPR','FontSize',15,'Fontweight','bold')
        ylabel('f-coefficient','FontSize',15,'Fontweight','bold')
        legend('DPR','DPN','northwest','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-f-old-new-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot([1:numel(qx0)]'/X.procRate/60,[q0a,q0b],'.')
        grid
        v = axis;
        v = [v(1) v(2) 20 80];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (%s)',stats0a.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Time [min]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
        legend('DPR','DPN','northwest','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-q-DPR-DPN-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot(q0a,[stats0a.sigma_q_trans],'.')
        grid
        v = axis;
        v = [v(1) v(2) 0 2];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (%s)',stats1.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
        legend('Trans','location','northwest','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-q0s-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot(q1,[stats1.sigma_q_trans,stats1.sigma_q_resid, sigma_q1],'.')
        grid
        v = axis;
        v = [v(1) v(2) 0 2];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR, DPN, %s)',stats1.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
        legend('Trans','Resid','total','location','northwest','FontSize',15,'Fontweight','bold')
        saveas(gcf,['./figs/q1s-' DP1str '.png'])
        ss = sprintf("./figs/Fig%i-q1s-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot(q1,[stats1.sigma_f_trans,stats1.sigma_f_resid, sigma_f1],'.')
        grid
        v = axis;
        v = [v(1) v(2) 0 0.15];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR, DPN %s)',stats1.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_f','FontSize',15,'Fontweight','bold')
        legend('Trans','Resid','total','location','northwest','FontSize',15,'Fontweight','bold')
        saveas(gcf,['./figs/f1s-' DP1str '.png'])
        ss = sprintf("./figs/Fig%i-f1s-%s.png",nn,DP1str)
        saveas(gcf,ss);
        
    nn = nn+1
    figure(nn)
        plot(q2,[stats2.sigma_q_trans,stats2.sigma_q_resid, sigma_q2],'.')
        grid
        v = axis;
        if contains(DP1str,'DP1')
            v = [v(1) v(2) 0 2];
        else
            v = [v(1) v(2) 1 3];
        end
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR + DPN + fcoef + %s)',stats2.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
        legend('Trans','Resid','total','location','northwest','FontSize',15,'Fontweight','bold')
        saveas(gcf,['./figs/q2s-' DP1str '.png'])
        ss = sprintf("./figs/Fig%i-q2s-%s.png",nn,DP1str)
        saveas(gcf,ss);
   
    nn = nn+1
    figure(nn)
        plot(q1,[stats1.q_ci(:,1),q1,stats1.q_ci(:,2)],'.');
        grid
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        v = axis;
        v = [v(1) v(2) 25 85];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR, DPN %s)',stats1.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        legend('Lower CI','Q\_impact','Upper CI','location','best','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-q1_ci-%s.png",nn,DP1str)
        saveas(gcf,ss);

    nn = nn+1
    figure(nn)
        plot(q2,[stats2.q_ci(:,1),q2,stats2.q_ci(:,2)],'.');
        grid
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        v = axis;
        v = [v(1) v(2) 25 85];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR + DPN + fcoef + %s)',stats2.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        legend('Lower CI','Q\_impact','Upper CI','location','northwest','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-q2_ci-%s.png",nn,DP1str)
        saveas(gcf,ss);

    nn = nn+1
    figure(nn)
        plot(q1,[stats1.f_ci(:,1),f1,stats1.f_ci(:,2)],'.');
        grid
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('f-coeff [dim]','FontSize',15,'Fontweight','bold')
        v = axis;
        v = [v(1) v(2) 1 3];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR + DPN  + %s)',stats2.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',10,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        legend('Lower CI','f-coeff','Upper CI','location','northwest','FontSize',10,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-f1-ci-%s.png",nn,DP1str)
        saveas(gcf,ss);
    
    nn = nn+1
    figure(nn)
        plot(q3,[stats3.q_ci(:,1),q3,stats3.q_ci(:,2)],'.');
        grid
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        v = axis;
        v = [v(1) v(2) 25 85];
        axis(v);
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        dofs = sprintf('dof = %i (DPR + DPN + f_sim + PTB %s)',stats3.dof,DP1str);
        text(0.5*rangex, v(4)-0.1*rangey,dofs,'FontSize',10,'Fontweight','bold')
        tytle1 = sprintf("%s Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        legend('Lower CI','f-coeff','Upper CI','location','northwest','FontSize',10,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-q3-ci-%s.png",nn,DP1str)
        saveas(gcf,ss);


    nn = nn+1
    figure(nn)
        v1 = stats1.valid;
        v2 = stats2.valid;
        subplot(2,1,1)
        plot(q1(v1), stats1.sigma_q_resid(v1), 'b.', ...
             q2(v2), stats2.sigma_q_resid(v2), 'r.')
        grid
        v = axis
        v1 = stats1.valid;
        v2 = stats2.valid;
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        legend('no f\_sim','with f\_sim','location','northwest','FontSize',15,'Fontweight','bold')
        tytle1 = sprintf("%s (resid) Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
                
        subplot(2,1,2)
        plot(q1(v1), stats1.sigma_q_trans(v1), 'b.', ...
             q2(v2), stats2.sigma_q_trans(v2), 'r.')
        grid
        v = axis;
        v = axis;
        axis([v(1) v(2) .015 .04]);
        v = axis;
        rangex = v(2)-v(1);
        rangey = v(4)-v(3);
        tytle1 = sprintf("%s (trans) Fig %i",tytle,nn);
        title(tytle1,'FontSize',15,'Fontweight','bold')
        legend('no f\_sim','with f\_sim','location','northwest','FontSize',15,'Fontweight','bold')
        xlabel('Q\_impact [hPa]','FontSize',15,'Fontweight','bold')
        ylabel('sigma\_q','FontSize',15,'Fontweight','bold')
        ss = sprintf("./figs/Fig%i-Valids-%s.png",nn,DP1str)
        saveas(gcf,ss);
            