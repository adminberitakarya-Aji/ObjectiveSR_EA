//+------------------------------------------------------------------+
//| SRClusterEngine.mqh - ObjectiveSR M4                              |
//| Merge 10-pip + Score (tipe source beda) + Zone. Center = MEDIAN.  |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_CLUSTER_ENGINE_MQH__
#define __OBJECTIVE_SR_CLUSTER_ENGINE_MQH__
#include "include/SRTypes.mqh"
#include "include/SRConfig.mqh"
#include "include/SRUtils.mqh"
//--- Prioritas source (tie-break deterministik, H4 swing terkuat)
int SourceRank(ENUM_SR_SOURCE s)
  {
   switch(s)
     {
      case SR_SOURCE_H4_SWING_HIGH: return(0);
      case SR_SOURCE_H4_SWING_LOW:  return(1);
      case SR_SOURCE_PWH:           return(2);
      case SR_SOURCE_PWL:           return(3);
      case SR_SOURCE_PDH:           return(4);
      case SR_SOURCE_PDL:           return(5);
      case SR_SOURCE_ASIA_HIGH:     return(6);
      case SR_SOURCE_ASIA_LOW:      return(7);
      case SR_SOURCE_ROUND_NUMBER:  return(8);
     }
   return(9);
  }
//--- Sort level by price asc (insertion, deterministik, n kecil)
void SortLevelsByPrice(SRLevel &lv[])
  {
   int n=ArraySize(lv);
   for(int i=1;i<n;i++)
     { SRLevel k=lv[i]; int j=i-1;
       while(j>=0 && lv[j].Price>k.Price){lv[j+1]=lv[j]; j--;}
       lv[j+1]=k; }
  }
//--- Median dari array harga yg sudah sort asc
double MedianOf(double &a[])
  {
   int n=ArraySize(a); if(n<=0) return(0);
   if(n%2==1) return(a[n/2]);
   return((a[n/2-1]+a[n/2])/2.0);
  }
//--- Score = jumlah tipe source BERBEDA (pakai IsSameSource)
int ScoreOf(SRLevel &grp[], int cnt)
  {
   int u=0; ENUM_SR_SOURCE seen[9]; int ns=0;
   for(int i=0;i<cnt;i++)
     { bool f=false;
       for(int j=0;j<ns;j++) if(IsSameSource(seen[j],grp[i].Source)){f=true;break;}
       if(!f){seen[ns]=grp[i].Source; ns++; u++;} }
   return(u);
  }
//--- Build satu cluster dari grup level
void FillCluster(string sym, SRSymbolConfig &sc, SRLevel &grp[], int cnt,
                 SRCluster &c)
  {
   double pr[]; ArrayResize(pr,cnt);
   for(int i=0;i<cnt;i++) pr[i]=grp[i].Price;
   // pr sudah asc dari grup yg diambil berurutan setelah sort
   double center=MedianOf(pr);
   double half=PipsToPrice(sym,sc.ZoneHalfPips);
   c.Center=center; c.ZoneWidth=half*2.0;
   c.Upper=center+half; c.Lower=center-half;
   c.SourceCount=ScoreOf(grp,cnt);
   c.TouchCount=0; c.State=SR_STATE_ACTIVE; c.FreshState=SR_FRESH;
   c.CreatedTime=TimeGMT(); c.LastTouchTime=0; c.LevelCount=cnt;
  }
//--- ClusterLevels: sort asc, greedy merge jarak<=ClusterDistance
int ClusterLevels(string sym, SRSymbolConfig &sc, SRLevel &lv[],
                  SRCluster &cl[])
  {
   ArrayResize(cl,0);
   int n=ArraySize(lv); if(n<=0) return(0);
   SortLevelsByPrice(lv);
   double dist=PipsToPrice(sym,sc.ClusterDistancePips);
   SRLevel grp[]; ArrayResize(grp,0);
   double gstart=lv[0].Price;
   for(int i=0;i<n;i++)
     {
      if(ArraySize(grp)==0){gstart=lv[i].Price;
        ArrayResize(grp,1); grp[0]=lv[i]; continue;}
      if(lv[i].Price-gstart<=dist+1e-9)
        {int m=ArraySize(grp); ArrayResize(grp,m+1); grp[m]=lv[i];}
      else
        {int k=ArraySize(cl); ArrayResize(cl,k+1);
         FillCluster(sym,sc,grp,ArraySize(grp),cl[k]);
         ArrayResize(grp,1); grp[0]=lv[i]; gstart=lv[i].Price;}
     }
   if(ArraySize(grp)>0)
     {int k=ArraySize(cl); ArrayResize(cl,k+1);
      FillCluster(sym,sc,grp,ArraySize(grp),cl[k]);}
   return(ArraySize(cl));
  }
//--- Rebuild penuh: levels -> clusters
int RebuildClusters(string sym, SRSymbolConfig &sc, SRLevel &lv[],
                    SRCluster &cl[])
  { return(ClusterLevels(sym,sc,lv,cl)); }
#endif
