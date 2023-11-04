#!/bin/bash
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

echoerr() { printf "$1" ${*:2} >&2; }

echodebug() { [[ "$DEBUG_LEVEL" == "debug" ]] && printf "$1" ${*:2} >&2; }

_FS="|";

# Okay so it defines a function called read_dom. The first line makes IFS
# (the input field separator) local to this function and changes it to >.
# That means that when you read data instead of automatically being split on
# space, tab or newlines it gets split on '>'. The next line says to read
# input from stdin, and instead of stopping at a newline, stop when you see
# a '<' character (the -d for deliminator flag). What is read is then split
# using the IFS and assigned to the variable ENTITY and CONTENT. So take the
# following:
#
#<tag>value</tag>
#
# The first call to read_dom get an empty string (since the '<' is the first
# character). That gets split by IFS into just '', since there isn't a '>'
# character. Read then assigns an empty string to both variables. The second
# call gets the string 'tag>value'. That gets split then by the IFS into the
# two fields 'tag' and 'value'. Read then assigns the variables like:
# ENTITY=tag and CONTENT=value. The third call gets the string '/tag>'. That
# gets split by the IFS into the two fields '/tag' and ''. Read then assigns
# the variables like: ENTITY=/tag and CONTENT=. The fourth call will return a
# non-zero status because we've reached the end of file.
#
# Now his while loop cleaned up a bit to match the above:
# 
# while read_dom; do
#     if [[ $ENTITY = "title" ]]; then
#         echo $CONTENT
#         exit
#     fi
# done < xhtmlfile.xhtml > titleOfXHTMLPage.txt
#
# https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
#
# Modo de uso:
# cat archivo.xml | read_parse_dom
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
    local ret=$?
    # Limpiar caracter de cierre de tag al final: /> o ?>
    [[ "${ENTITY:(-1)}" == '/' || "${ENTITY:(-1)}" == '?' ]] && ENTITY="${ENTITY::-1}"
    TAG_NAME=${ENTITY%% *}
    ATTRIBUTES=${ENTITY#* }
    return $ret
}

parse_dom () {
    # if [[ $TAG_NAME = "foo" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "foo size is: $size"
    # elif [[ $TAG_NAME = "bar" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "bar type is: $type"
    # fi
    printf "ENTITY =[%s]\n" "$ENTITY"
    printf "CONTENT=[%s]\n" "$CONTENT"
    printf "TAG_NAME  =[%s]\n" "$TAG_NAME"
    printf "ATTRIBUTES=[%s]\n" "$ATTRIBUTES"
}

read_parse_dom () {
    while read_dom; do
        parse_dom
    done
}

function parseElementAttributesByStr () {
    [ -z "${1}" ] && { echo "Falta arreglo con los atributos del elemento DOM"; return 1; }
    [ -z "${2}" ] && { echo "Falta str con el contenido de los atributos del elemento DOM a parsear"; return 1; }
    local _FS="$_FS"
    [ -n "${3}" ] && _FS="${3}"
    local atributos="$1[@]"
    atributos=("${!atributos}")
    local strToParse="${2}"
    eval local $strToParse 2>/dev/null
    local primero=1;
    local title=""
    local record=""
    local tmp1=""
    local tmp2=""
    
    # Es posible que un atributo pueda ser llamado de dos formas, esto por la
    # version de la implemtación de la version del xml o la falta de estandarizacion
    for atributo in ${atributos[@]}; do
        # Se puede poner nombres alternativos a un mismo atributos, separar con pipe
        _atributo="${atributo}"
        if [[ "${atributo}" =~ "|" ]]; then
            # nombre de atributo multiple
            # Verificar cuál, de las opciones indicadas, existe
            local _tmpIFS=$IFS;
            IFS="|";
            for _attr in $atributo; do
                _atributo="${_attr}"
                [ ! -z ${!_attr} ] && break;
            done
        fi
        if [[ $primero -eq 1 ]]; then
            printf -v title "%s" "${_atributo}"
            # Indirect variable reference
            # https://unix.stackexchange.com/questions/41406/use-a-variable-reference-inside-another-variable
            printf -v record "%s" "${!_atributo}"
            primero=0;
        else
            printf -v tmp1 "${_FS}%s" "${_atributo}"
            # Indirect variable reference
            # https://unix.stackexchange.com/questions/41406/use-a-variable-reference-inside-another-variable
            printf -v tmp2 "${_FS}%s" "${!_atributo}"

            title="${title}${tmp1}"
            record="${record}${tmp2}"
        fi
    done
    printf "%s\n%s" "$title" "$record"
}

function __stack_clear() {
    local profundidad=( )
    if [[ -z "$TMP" ]]; then
        TMP=/tmp
    fi
    __workingDirectory="$TMP/cfdi"
    if [[ ! -d "$__workingDirectory" ]]; then
        mkdir -p "$__workingDirectory"
    fi
    __tmpfile="$__workingDirectory/xml_profundidad.log"
    if [[ -f "$__tmpfile" ]]; then
        profundidad=($(cat "$__tmpfile" ))
    fi
    echo > "$__tmpfile"
}

function __stack_push () {
    [[ -z "$1" ]] && { echoerr "Falta valor a agregar"; }
    local profundidad=( )
    if [[ -z "$TMP" ]]; then
        TMP=/tmp
    fi
    __workingDirectory="$TMP/cfdi"
    if [[ ! -d "$__workingDirectory" ]]; then
        mkdir -p "$__workingDirectory"
    fi
    __tmpfile="$__workingDirectory/xml_profundidad.log"
    if [[ -f "$__tmpfile" ]]; then
        profundidad=($(cat "$__tmpfile" ))
    fi
    profundidad=( "${profundidad[@]}" "$1" )
    printf "%s " "${profundidad[@]}" > "$__tmpfile"
}

function __stack_pop () {
    local profundidad=( )
    if [[ -z "$TMP" ]]; then
        TMP=/tmp
    fi
    __workingDirectory="$TMP/cfdi"
    if [[ ! -d "$__workingDirectory" ]]; then
        mkdir -p "$__workingDirectory"
    fi
    __tmpfile="$__workingDirectory/xml_profundidad.log"
    if [[ -f "$__tmpfile" ]]; then
        profundidad=($(cat "$__tmpfile" ))
    fi
    if [[ ${#profundidad[@]} -eq 0 ]]; then
        echoerr "${RED}ERR${NORMAL} No hay elementos en la pila para retirar"
    else
        unset 'profundidad[-1]';
        printf "%s" "${profundidad[@]}" > "$__tmpfile"
    fi
}

function __stack_peek () {
    local profundidad=( )
    if [[ -z "$TMP" ]]; then
        TMP=/tmp
    fi
    __workingDirectory="$TMP/cfdi"
    if [[ ! -d "$__workingDirectory" ]]; then
        mkdir -p "$__workingDirectory"
    fi
    __tmpfile="$__workingDirectory/xml_profundidad.log"
    if [[ -f "$__tmpfile" ]]; then
        profundidad=($(cat "$__tmpfile" ))
    fi
    if [[ ${#profundidad[@]} -eq 0 ]]; then
        echoerr "${RED}ERR${NORMAL} No hay elementos en la pila"
    else
        printf "%s" "${profundidad[-1]}";
    fi
}

function __stack_size () {
    local profundidad=( )
    if [[ -z "$TMP" ]]; then
        TMP=/tmp
    fi
    __workingDirectory="$TMP/cfdi"
    if [[ ! -d "$__workingDirectory" ]]; then
        mkdir -p "$__workingDirectory"
    fi
    __tmpfile="$__workingDirectory/xml_profundidad.log"
    if [[ -f "$__tmpfile" ]]; then
        profundidad=($(cat "$__tmpfile" ))
    fi
    printf "%s" "${#profundidad[@]}";
}

parse_cfdi () {
    # if [[ $TAG_NAME = "foo" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "foo size is: $size"
    # elif [[ $TAG_NAME = "bar" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "bar type is: $type"
    # fi
    # Con cada invocación, se vaciaba la pila profundidad
    # 

    # Atributos a obtener por elemento XML
    local cfdi_Comprobante=(
        "Version"
        "Serie"
        "Folio"
        "Fecha"
        "FormaPago"
        "CondicionesDePago"
        "SubTotal"
        "Moneda"
        "Total"
        "TipoDeComprobante"
        "MetodoPago"
        "LugarExpedicion"
        "Exportacion"
        # "Certificado"
        # "NoCertificado"
        # "Sello"
        )
    local cfdi_InformacionGlobal=(
        "Periodicidad"
        "Meses"
        # "Año"
        )
    local cfdi_Emisor=(
        "Rfc"
        "Nombre"
        "RegimenFiscal"
        )
    local cfdi_Receptor=(
        "Rfc"
        "Nombre"
        "DomicilioFiscalReceptor"
        "RegimenFiscalReceptor"
        "UsoCFDI"
        )
    local cfdi_Concepto=(
        "ClaveProdServ"
        "Cantidad"
        "ClaveUnidad"
        "Unidad"
        "Descripcion"
        "ValorUnitario"
        "Importe"
        "ObjetoImp"
        )
    local cfdi_Concepto_Traslado=(
        "Base"
        "Impuesto"
        "TipoFactor"
        "TasaOCuota"
        "Importe"
        )
    local cfdi_Impuestos=(
        "TotalImpuestosTrasladados"
        )
    local cfdi_ImpuestosTrasladados=(
        "Impuesto"
        "TipoFactor"
        "TasaOCuota"
        "Importe"
        )
    local tfd_TimbreFiscalDigital=(
        "UUID"
        "FechaTimbrado"
        )
    local nomina12_Percepciones=(
        TotalSueldos
        TotalGravado
        TotalExento
        )
    local nomina12_Deducciones=(
        TotalOtrasDeducciones
        TotalImpuestosRetenidos
        )
    case $TAG_NAME in
        "cfdi:Comprobante" )
            parseElementAttributesByStr cfdi_Comprobante "$ATTRIBUTES"
            echo
            ;;
        "cfdi:InformacionGlobal" )
            # parseElementAttributesByStr cfdi_InformacionGlobal "$ATTRIBUTES"
            # echo
            ;;
        "cfdi:Emisor" )
            parseElementAttributesByStr cfdi_Emisor "$ATTRIBUTES"
            echo
            ;;
        "cfdi:Receptor" )
            parseElementAttributesByStr cfdi_Receptor "$ATTRIBUTES"
            echo
            ;;
        "cfdi:Conceptos" )
            __stack_push "$TAG_NAME"
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            echodebug "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            ;;
        "cfdi:Concepto" )
            __stack_push "$TAG_NAME"
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            echodebug "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            # parseElementAttributesByStr cfdi_Concepto "$ATTRIBUTES"
            # echo
            ;;
        "/cfdi:Concepto" )
            __stack_pop;
            ;;
        "cfdi:Impuestos" )
            local _size=$(__stack_size)
            if [[ ${_size} -eq 0 ]]; then
                __stack_push "$TAG_NAME"
                parseElementAttributesByStr cfdi_Impuestos "$ATTRIBUTES"
                echo
            fi
            ;;
        "cfdi:Traslados" )
            ;;
        "cfdi:Traslado" )
            # Solo considerar los impuestos trasladados del nodo impuestos,
            # donde se tiene el atributo TotalImpuestosTrasladados
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            echodebug "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            if [[ ${_size} -eq 2 ]]; then
                if [[ ${_peek} == "cfdi:Traslados" ]]; then
                    parseElementAttributesByStr cfdi_ImpuestosTrasladados "$ATTRIBUTES"
                    echo
                fi
            fi
            ;;
        "cfdi:Complemento" )
            ;;
        "nomina12:Percepciones" )
            parseElementAttributesByStr nomina12_Percepciones "$ATTRIBUTES"
            echo
            ;;
        "nomina12:Deducciones" )
            parseElementAttributesByStr nomina12_Deducciones "$ATTRIBUTES"
            echo
            ;;
        "tfd:TimbreFiscalDigital" )
            echodebug "$ATTRIBUTES"
            parseElementAttributesByStr tfd_TimbreFiscalDigital "$ATTRIBUTES"
            echo
            ;;
        \?* )
            #omitir tag <?xml>
            ;;
        \/* )
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            if [[ ${_size} -gt 0 ]] ; then
                echodebug "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tag_cierre:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${TAG_NAME}" "${_peek}"
                if [[ ${_peek} == "${TAG_NAME:1}" ]]; then
                    __stack_pop
                fi
            fi
            ;;
        * )
            # Tag no identificado previamente
            # printf "%s\n" "$TAG_NAME"
            ;;
    esac
}

# Modo de uso:
# cat archivo.xml | read_parse_cfdi
read_parse_cfdi () {
    _OUT=""
    _TITLE=""
    _REC=""
    primero=1
    __stack_clear
    while read_dom; do
        _OUT=$(parse_cfdi)
        echodebug "${CYAN}TAG_NAME:${NORMAL}%s\n" ${TAG_NAME}
        if [[ "${#_OUT}" -gt 0 ]]; then
            if [[ "$TAG_NAME" == "cfdi:Comprobante" && primero -eq 1 ]]; then
                _TITLE="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $1}' <<< "$_OUT")"
                _REC="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $2}' <<< "$_OUT")"
                primero=0
            else
                if [[ "$TAG_NAME" == "cfdi:Impuestos" ]]; then
                    echodebug "${CYAN}#_OUT:${NORMAL}%s\n" ${_OUT}
                fi
                _TITLE="${_TITLE}|$(awk 'BEGIN{FS="\n"; RS="^^"}{print $1}' <<< "$_OUT")"
                _REC="${_REC}|$(awk 'BEGIN{FS="\n"; RS="^^"}{print $2}' <<< "$_OUT")"
            fi
        fi
    done
    if [[ "$1" == "conEncabezado" ]]; then
        echo "$_TITLE"
    fi
    echo "$_REC"
}

parse_retencion () {
    # if [[ $TAG_NAME = "foo" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "foo size is: $size"
    # elif [[ $TAG_NAME = "bar" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "bar type is: $type"
    # fi
    # Con cada invocación, se vaciaba la pila profundidad
    # 

    # Atributos a obtener por elemento XML
    local retenciones_Retenciones=(
        "Version"
        "FolioInt"
        "FechaExp"
        "CveRetenc"
        # "Certificado"
        # "NoCertificado"
        # "Sello"
        )
    local retenciones_Emisor=(
        "RfcE|RFCEmisor"
        "NomDenRazSocE"
        "RegimenFiscalE"
        )
    local retenciones_Receptor=(
        "NacionalidadR|Nacionalidad"
        )
    local retenciones_Nacional=(
        "RfcR|RFCRecep"
        "NomDenRazSocR"
        "DomicilioFiscalR"
        )
    local retenciones_Periodo=(
        "MesIni"
        "MesFin"
        "Ejercicio|Ejerc"
        )
    local retenciones_Totales=(
        "MontoTotOperacion|montoTotOperacion"
        "MontoTotGrav|montoTotGrav"
        "MontoTotExent|montoTotExent"
        "MontoTotRet|montoTotRet"
        )
    local retenciones_ImpRetenidos=(
        "BaseRet"
        "Impuesto"
        "montoRet"
        "TipoPagoRet"
        )
    local plataformasTecnologicas_ServiciosPlataformasTecnologicas=(
        "Periodicidad"
        "NumServ"
        "MonTotServSIVA"
        "TotalIVATrasladado"
        "TotalIVARetenido"
        "TotalISRRetenido"
        "DifIVAEntregadoPrestServ"
        "MonTotalporUsoPlataforma"
        )
    local tfd_TimbreFiscalDigital=(
        "UUID"
        )
    case $TAG_NAME in
        "retenciones:Retenciones" )
            parseElementAttributesByStr retenciones_Retenciones "$ATTRIBUTES"
            echo
            ;;
        "retenciones:Emisor" )
            parseElementAttributesByStr retenciones_Emisor "$ATTRIBUTES"
            echo
            ;;
        "retenciones:Receptor" )
            parseElementAttributesByStr retenciones_Receptor "$ATTRIBUTES"
            echo
            ;;
        "retenciones:Nacional" )
            parseElementAttributesByStr retenciones_Nacional "$ATTRIBUTES"
            echo
            ;;
        "retenciones:Periodo" )
            parseElementAttributesByStr retenciones_Periodo "$ATTRIBUTES"
            echo
            ;;
        "retenciones:Totales" )
            parseElementAttributesByStr retenciones_Totales "$ATTRIBUTES"
            echo
            ;;
        "retenciones:ImpRetenidos" )
            parseElementAttributesByStr retenciones_ImpRetenidos "$ATTRIBUTES" ":"
            echo
            ;;
        "plataformasTecnologicas:ServiciosPlataformasTecnologicas" )
            parseElementAttributesByStr plataformasTecnologicas_ServiciosPlataformasTecnologicas "$ATTRIBUTES"
            echo
            ;;
        "tfd:TimbreFiscalDigital" )
            parseElementAttributesByStr tfd_TimbreFiscalDigital "$ATTRIBUTES"
            echo
            ;;
        \?* )
            #omitir tag <?xml>
            ;;
        \/* )
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            if [[ ${_size} -gt 0 ]] ; then
                echodebug "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tag_cierre:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${TAG_NAME}" "${_peek}"
                if [[ ${_peek} == "${TAG_NAME:1}" ]]; then
                    __stack_pop
                fi
            fi
            ;;
        * )
            # Tag no identificado previamente
            #omitir tag <?xml>
            ;;
    esac
}

# Modo de uso:
# cat archivo.xml | read_parse_retencion
read_parse_retencion () {
    _OUT=""
    _TITLE=""
    _REC=""
    primero=1
    local _FS="|"
    local _FS2="+"
    local _countRetenciones=0;
    __stack_clear
    while read_dom; do
        _OUT=$(parse_retencion)
        echodebug "${CYAN}TAG_NAME:${NORMAL}%s\n" ${TAG_NAME}
        if [[ "${#_OUT}" -gt 0 ]]; then
            if [[ "$TAG_NAME" == "retenciones:Retenciones" && primero -eq 1 ]]; then
                _TITLE="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $1}' <<< "$_OUT")"
                _REC="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $2}' <<< "$_OUT")"
                primero=0
            else
                local _separador="$_FS"
                if [[ "$TAG_NAME" == "retenciones:ImpRetenidos" ]]; then
                    _countRetenciones=$((_countRetenciones+1))
                    [[ _countRetenciones -gt 1 ]] && _separador="$_FS2"
                fi
                if [[ "$TAG_NAME" == "tfd:TimbreFiscalDigital" ]]; then
                    [[ _countRetenciones -eq 0 ]] && _separador="${_FS}${_FS}"
                fi
                _TITLE="${_TITLE}${_separador}$(awk 'BEGIN{FS="\n"; RS="^^"}{print $1}' <<< "$_OUT")"
                _REC="${_REC}${_separador}$(awk 'BEGIN{FS="\n"; RS="^^"}{print $2}' <<< "$_OUT")"
            fi
        fi
    done
    if [[ "$1" == "conEncabezado" ]]; then
        echo "$_TITLE"
    fi
    echo "$_REC"
}

# cd $HOME_WIN/Downloads/borrame/facturas/2022/emitidas/
# source $HOME_WIN/Documents/Projects/uber/libxml.sh
# time { primero=1; output=cfdi_emitidas.txt; printf "" > "${output}"; for archivo in $(ls *.xml); do printf "." ; if [[ $primero -eq 1 ]]; then cat "$archivo" | read_parse_cfdi "conEncabezado" >> "${output}"; primero=0; else cat "$archivo" | read_parse_cfdi >> "${output}"; fi; done; echo; }
# /cygdrive/c/Users/Usuario/Downloads/borrame/facturas/2022/recibidas


function getISR() {
    [[ -z "$1" ]] && { echo "Uso: ${FUNCNAME[0]} archivo.xml"; return 1; }
    local archivo="$1"
    [[ ! -f "${archivo}" ]] && { echo "No existe archivo: [$1]"; return 1; }
    grep "Impuesto[Ret]*=\"[0]*1\"" "${archivo}" | grep -ioP "montoRet=\"\K([^\"]+)"
}

function getIVA() {
    [[ -z "$1" ]] && { echo "Uso: ${FUNCNAME[0]} archivo.xml"; return 1; }
    local archivo="$1"
    [[ ! -f "${archivo}" ]] && { echo "No existe archivo: [$1]"; return 1; }
    grep "Impuesto[Ret]*=\"[0]*2\"" "${archivo}" | grep -ioP "montoRet=\"\K([^\"]+)"
}

# Localizar facturas utiles (no recibos de nómina, no facturas con total=0)
# Obtiene la lista de facturas recibidas con path absoluto
# Modo de uso:
# recibidas=$(ls -d "$HOME_FACTURAS/recibidas"/*.xml)
#
# Se puede añadir un segundo filtro para determinar todas las de un mes, por
# ejemplo abril
#
# Notar que es necesario remplazar el separador interno de registros para
# evitar problemas con nombres de archivos que contenga espacios
#
# recibidasAbril=$(tmpIFS=$IFS; IFS=$'\n'; grep -l 'Fecha="2022-04' $recibidas; IFS=$tmpIFS;)
# identificarFacturasUtiles "$recibidas"
# De la siguiente forma obtenemos un listado útil para #identificarFacturasDeduccionesPersonales
# facturasGastos=$(identificarFacturasUtiles "$recibidasAbril")
#
# @param $1 - Listado de archivos XML (CFDI) de facturas (recibidas)
function identificarFacturasUtiles () {
    [[ -z "$1" ]] && { echoerr "Se requiere listado de archivos xml"; return 1; }
    facturasCandidatas="$1"
    facturas=();
    # Obliga a usar solamente \n como separador de registro en el listado de archivos entregados.
    # Esto evita problemas en nombre de directorios donde haya espacios
    local IFS=$'\n'
    # Identificar todos los XML con TipoDeComprobante="I" (ingreso)
    # De esta forma se valida: a) es un CFDI y; b) es de tipo ingreso (identificado como un gasto)
    for archivo in ${facturasCandidatas}; do
        _TMP=$(grep -o 'TipoDeComprobante="I"' "$archivo");
        [ $? -eq 0 ] && facturas=( ${facturas[@]} "$archivo" );
    done;

    # Identificar las facturas donde el total es diferente a 0
    for archivo in ${facturas[@]}; do
        _TMP=$(grep -oP 'Total="0[.0]*"' "$archivo");
        #[ $? -ne 0 ] && facturas=( ${facturas[@]} "$archivo" );
        [ $? -ne 0 ] && echo "$archivo";
    done;
}

# Identificar facturas XML CFDI que pertenezcan a ciertos RFCs emisores de
# deduccioes personales
#
# Se sugiere tener el listado de RFCs en un archivo indicando adicional alguna nota para saber de qué se trata
# Ej.
# listadoRFCDeducibles='/cygdrive/c/Users/PC BEAR/Dropbox/personal/fiscal/PlataformaTecnológicaUber/SAT/rfcEmisoresGastosDeducibles.txt'
# rfcDeducibles=$(cut -f1 "$listadoRFCDeducibles")
# deducciones=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles")
# gastos=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles" false)
#
# @param $1 - Listado de facturas
# @param $2 - Listado de RFCs de emisores de deducciones personales
# @param $3 - Opcional, si se indica false, regresa listado de archivos donde no exista rfcDeducibles
# @return Listado de archivos donde está rfcDeducibles. Si $3==false, regresa listado donde no encuentra rfcDeducibles
function identificarFacturasDeduccionesPersonales () {
    # set -x
    [[ -z "$1" ]] && { echoerr "Se requiere listado de archivos xml"; return 1; }
    [[ -z "$2" ]] && { echoerr "Se requiere listado de RFC a buscar"; return 1; }
    local _invertido=false
    [[ -n "$3" && "$3"=="false" ]] && _invertido=true;
    facturasCandidatas="$1"
    rfcEmisores="$2"
    echo "$rfcEmisores" > "$TMP/rfcEmisores.tmp"
    # Obliga a usar solamente \n como separador de registro en el listado de archivos entregados.
    # Esto evita problemas en nombre de directorios donde haya espacios
    local IFS=$'\n'
    for archivo in ${facturasCandidatas}; do
        _TMP=$(grep -f "$TMP/rfcEmisores.tmp" "$archivo");
        local _R=$?
        if [[ "$_invertido" == true ]]; then
            [ $_R -eq 1 ] && echo "$archivo";
        else
            [ $_R -eq 0 ] && echo "$archivo";
        fi
    done;
    rm "$TMP/rfcEmisores.tmp"
    # set +x
}

# Aplicar funcion despues de #identificarFacturasDeduccionesPersonales
function identificarGastosNoUtiles () {
    [[ -z "$1" ]] && { echoerr "Se requiere listado de archivos xml"; return 1; }
    [[ -z "$2" ]] && { echoerr "Se requiere listado de RFC a buscar"; return 1; }
    local _invertido=false
    [[ -n "$3" && "$3"=="false" ]] && _invertido=true;
    facturasCandidatas="$1"
    rfcEmisores="$2"
    echo "$rfcEmisores" > "$TMP/rfcEmisoresNoUtil.tmp"
    # Obliga a usar solamente \n como separador de registro en el listado de archivos entregados.
    # Esto evita problemas en nombre de directorios donde haya espacios
    local IFS=$'\n'
    for archivo in ${facturasCandidatas}; do
        _TMP=$(grep -f "$TMP/rfcEmisoresNoUtil.tmp" "$archivo");
        local _R=$?
        if [[ "$_invertido" == true ]]; then
            [ $_R -eq 1 ] && echo "$archivo";
        else
            [ $_R -eq 0 ] && echo "$archivo";
        fi
    done;
    rm "$TMP/rfcEmisoresNoUtil.tmp"
}

# HOME_SAT="/cygdrive/c/Users/PC BEAR/Dropbox/personal/fiscal/PlataformaTecnológicaUber/SAT"
# HOME_FACTURAS="${HOME_SAT}/facturas"
# cd "$HOME_PROJECT/mxsatuber"
# source libxml.sh
# recibidas=$(find "$HOME_FACTURAS" -iname *.xml)
# listadoRFCDeducibles="${HOME_SAT}/rfcEmisoresGastosDeducibles.txt"
# listadoRFCNoUtil="${HOME_SAT}/rfcEmisoresGastosNoUtil.txt"
# rfcDeducibles=$(cut -f1 "$listadoRFCDeducibles")
# rfcNoUtil=$(cut -f1 "$listadoRFCNoUtil")
# ANNIO=2022
# MES=04
# recibidasMes=$(tmpIFS=$IFS; IFS=$'\n'; grep -l 'Fecha="'$ANNIO'-'$MES $recibidas; IFS=$tmpIFS;)
# facturasGastos=$(identificarFacturasUtiles "$recibidasMes")
# deducciones=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles")
# gastos=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles" false)
# gastos=$(identificarGastosNoUtiles "$gastos" "$rfcNoUtil" false)
# registros=$(tmpIFS=$IFS; IFS=$'\n'; for archivo in $gastos; do cat "$archivo" | read_parse_cfdi; done; IFS=$tmpIFS;)
# Imprimir los registros en formato compatible con "HOJA DE TRABAJO"
# awk -f gastos.awk <<< "$registros"

# Obtiene los gastos "utiles" del año indicado
# @param PATH_FACTURAS - Ruta donde están las facturas CFDI (xml) de los gastos
# @param AÑO - Año del ejercicio fiscal 
function getGastos() {
    [[ -z "$1" ]] && { echoerr "Indique path padre donde están las facturas xml. Se hará una búsqueda en profundidad buscando por archivos XML a partir de la ruta indicada"; return 1; }
    [[ -z "$2" ]] && { echoerr "Indique el año fiscal"; return 1; }
    [[ -z "$3" ]] && { echoerr "Indique archivo con listado de RFC deducibles"; return 1; }
    [[ -z "$4" ]] && { echoerr "Indique archivo con listado de RFC no utiles como gastos"; return 1; }
    local _path_facturas="${1}"
    local ANNIO="${2}"
    local listadoRFCDeducibles="${3}"
    local listadoRFCNoUtil="${4}"
    local recibidas=$(find "${_path_facturas}" -iname *.xml)
    local rfcDeducibles=$(cut -f1 "$listadoRFCDeducibles")
    local rfcNoUtil=$(cut -f1 "$listadoRFCNoUtil")
    local _OUT=""
    local _LF=""
    for MES in {1..12}; do
        echoerr "Procesando mes %02d-%d\n" ${MES} ${ANNIO}
        # Identificar CFDI/XML eimitidos del mes
        recibidasMes=$(tmpIFS=$IFS; IFS=$'\n'; grep -lP 'Fecha="'$ANNIO'-0?'$MES $recibidas; IFS=$tmpIFS;)
        # De lo recibido del mes, identificar los posibles candidatos de gastos
        # echo "$recibidasMes"
        [[ -z "$recibidasMes" ]] && continue;
        facturasGastos=$(identificarFacturasUtiles "$recibidasMes")
        # Las deducciones no son computables como gastos, sirve para la declaracion anual
        deducciones=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles")
        # Busca las facturas que no son deducciones = gastos útiles para declaracion mensual
        gastos=$(identificarFacturasDeduccionesPersonales "$facturasGastos" "$rfcDeducibles" false)
        # echo "$gastos"
        # De los gastos indentificados, eliminar los que no son útiles
        gastos=$(identificarGastosNoUtiles "$gastos" "$rfcNoUtil" false)
        # Analizar cada gasto (archivo xml)
        registros=$(tmpIFS=$IFS; IFS=$'\n'; for archivo in $gastos; do cat "$archivo" | read_parse_cfdi; done; IFS=$tmpIFS;)
        #echo "$registros"
        # Imprimir reporte
        [[ $MES -gt 1 ]] && printf -v _LF "\n"
        printf -v _OUT "%s%s$(awk -f gastos.awk <<< "$registros")" "${_OUT}" "$_LF"
    done
    sort -u <<< "$_OUT"
}

# ANNIO=2022
# retenciones=$(find "$HOME_FACTURAS" -iname *.xml)
# MES=5
# 
# retencionesMes=$(tmpIFS=$IFS; IFS=$'\n'; grep -lP 'Periodo [^"]+"[^"]+" MesFin="0?'$MES'" (Ejerc|Ejercicio)="'$ANNIO'"' $retenciones; IFS=$tmpIFS;)
# registros=$(tmpIFS=$IFS; IFS=$'\n'; for archivo in $retencionesMes; do cat "$archivo" | read_parse_retencion; done; IFS=$tmpIFS;)
# awk 'BEGIN{FS="|";OFS=FS;}{print $27,$5,$6,$9,$10,$3,$13,$14,$15,$24,$23}' <<< "$registros"
#
# for MES in {1..12}; do
#   retencionesMes=$(tmpIFS=$IFS; IFS=$'\n'; grep -lP 'Periodo [^"]+"[^"]+" MesFin="0?'$MES'" (Ejerc|Ejercicio)="'$ANNIO'"' $retenciones; IFS=$tmpIFS;)
#   registros=$(tmpIFS=$IFS; IFS=$'\n'; for archivo in $retencionesMes; do cat "$archivo" | read_parse_retencion; done; IFS=$tmpIFS;)
#   #echo "$registros"
#   awk -f retencion.awk <<< "$registros"
# done

# Encontrar factura
# cygpath -w "$(find "$HOME_FACTURAS" -iname *.xml | grep -i $UUID)"

function identificarRetencionesPorRFC () {
    # set -x
    [[ -z "$1" ]] && { echoerr "Se requiere listado de archivos xml"; return 1; }
    [[ -z "$2" ]] && { echoerr "Se requiere listado de RFC a buscar"; return 1; }
    local _invertido=false
    [[ -n "$3" && "$3"=="false" ]] && _invertido=true;
    local facturasCandidatas="$1"
    local rfcRetenedor="$2"
    local rfcDeducibles=$(cut -f1 "$listadoRFCDeducibles")
    echo "$rfcRetenedor" > "$TMP/rfcRetenedor.tmp"
    # Obliga a usar solamente \n como separador de registro en el listado de archivos entregados.
    # Esto evita problemas en nombre de directorios donde haya espacios
    local IFS=$'\n'
    for archivo in ${facturasCandidatas}; do
        _TMP=$(grep -f "$TMP/rfcRetenedor.tmp" "$archivo");
        local _R=$?
        [ $_R -eq 0 ] && echo "$archivo";
    done;
    rm "$TMP/rfcRetenedor.tmp"
    # set +x
}

function getRetenciones() {
    [[ -z "$1" ]] && { echoerr "Indique path padre donde están las facturas xml. Se hará una búsqueda en profundidad buscando por archivos XML a partir de la ruta indicada"; return 1; }
    [[ -z "$2" ]] && { echoerr "Indique el año fiscal"; return 1; }
    local _path_facturas="${1}"
    local ANNIO="${2}"
    local listadoRFCRetenedores="${3}"
    local retenciones=$(find "${_path_facturas}" -iname *.xml)

    if [[ -n "${3}" ]]; then
        [[ ! -f "${listadoRFCRetenedores}" ]] && { echoerr "No es un archivo: ${listadoRFCRetenedores}"; return 1; }
        local rfcRetenedor=$(cut -f1 "$listadoRFCRetenedores")
        retenciones=$(identificarRetencionesPorRFC "$retenciones" "$rfcRetenedor")
    fi

    # [[ -n "$3" ]] && { echoerr "Indique archivo con listado de RFC retenedores"; return 1; }
    local _OUT=""
    local _LF=""
    for MES in {1..12}; do
        echoerr "Procesando mes %02d-%d\n" ${MES} ${ANNIO}
        retencionesMes=$(tmpIFS=$IFS; IFS=$'\n'; grep -lP 'Periodo [^"]+"[^"]+" MesFin="0?'$MES'" (Ejerc|Ejercicio)="'$ANNIO'"' $retenciones; IFS=$tmpIFS;)
        [[ -z "$retencionesMes" ]] && continue;
        registros=$(tmpIFS=$IFS; IFS=$'\n'; for archivo in $retencionesMes; do cat "$archivo" | read_parse_retencion; done; IFS=$tmpIFS;)
        #echo "$registros"
        awk -f retencion.awk <<< "$registros"
    done
}