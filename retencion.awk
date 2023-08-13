function sumarRet(campo,tipoRetencion) {
    suma=0;
    if(campo!="") {
        n=split($19,retenciones,"+");
        for(retencion in retenciones) {
            m=split(retencion,valor,":");
            if(m>0) {
                if(m>=3) {
                    if(valor[1]==tipoRetencion){
                        suma+=valor[2];
                    }
                }
            }
        }
    }
    return suma;
}
BEGIN {
    FS="|";
    OFS=FS;
    tipoIVA=1;
    tipoISR=2;
}{
    print ($28!=""?$28:$20),$5,$6,$9,$10,$3,$13,$14,$15,($24!=""?$24:($18==0?$18:sumarRet(tipoISR))),($23!=""?$23:($18==0?$18:sumarRet(tipoIVA)))
}