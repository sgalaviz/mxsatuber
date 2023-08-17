function sumarRet(campo,tipoRetencion) {
    #print("<"campo","tipoRetencion">");
    suma=0;
    if(campo!="") {
        # index inicia en 1
        n=split(campo,retenciones,"+");
        # print(retenciones[1]);
        for(idx in retenciones) {
            m=split(retenciones[idx],valor,":");
            if(m>0) {
                if(m>=3) {
                    if((valor[2]+0)==tipoRetencion){
                        return valor[3];
                        suma+=valor[3];
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
    tipoIVA=2;
    tipoISR=1;
}{
    print(($28!=""?$28:$20),$5,$6,$9,$10,$3,$13,$14,$16,($25!=""?$25:($16==0?$16:sumarRet($19,tipoISR))),($24!=""?$24:($16==0?$16:sumarRet($19,tipoIVA))));
}