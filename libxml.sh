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

echodebug() { [ "$DEBUG_LEVEL" == "debug" ] && printf "$1" ${*:2} >&2; }

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
    local atributos="$1[@]"
    atributos=("${!atributos}")
    local strToParse="${2}"
    eval local $strToParse 2>/dev/null
    local primero=1;
    local title=""
    local record=""
    local tmp1=""
    local tmp2=""
    for atributo in ${atributos[@]}; do
        if [[ $primero -eq 1 ]]; then
            printf -v title "%s" "${atributo}"
            # Indirect variable reference
            # https://unix.stackexchange.com/questions/41406/use-a-variable-reference-inside-another-variable
            printf -v record "%s" "${!atributo}"
            primero=0;
        else
            printf -v tmp1 "${_FS}%s" "${atributo}"
            # Indirect variable reference
            # https://unix.stackexchange.com/questions/41406/use-a-variable-reference-inside-another-variable
            printf -v tmp2 "${_FS}%s" "${!atributo}"

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
    set +xT
    # if [[ $TAG_NAME = "foo" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "foo size is: $size"
    # elif [[ $TAG_NAME = "bar" ]] ; then
    #     eval local $ATTRIBUTES
    #     echo "bar type is: $type"
    # fi
    # Con cada invocación, se vaciaba la pila profundidad
    # 
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
    local cfdi_Traslado=(
        "Base"
        "Impuesto"
        "TipoFactor"
        "TasaOCuota"
        "Importe"
        )
    local cfdi_Impuestos=(
        "TotalImpuestosTrasladados"
        )
    local tfd_TimbreFiscalDigital=(
        "UUID"
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
            echoerr "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            ;;
        "cfdi:Concepto" )
            __stack_push "$TAG_NAME"
            local _size=$(__stack_size)
            local _peek=$(__stack_peek 2>/dev/null)
            echoerr "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            # parseElementAttributesByStr cfdi_Concepto "$ATTRIBUTES"
            # echo
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
            echoerr "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${_peek}"
            if [[ ${_size} -gt 0 ]]; then
                if [[ ${_peek} == "cfdi:Impuestos" ]]; then
                    parseElementAttributesByStr cfdi_Traslado "$ATTRIBUTES"
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
                echoerr "${CYAN}Profundidad:${NORMAL}%s\t${CYAN}Tag_cierre:${NORMAL}%s\t${CYAN}Tope_Pila:${NORMAL}%s\n" "${_size}" "${TAG_NAME}" "${_peek}"
                if [[ ${_peek} == "${TAG_NAME:1}" ]]; then
                    __stack_pop
                fi
            fi
            ;;
        * )
            # Tag no identificado previamente
            printf "%s\n" "$TAG_NAME"
            ;;
    esac
    set -xT
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
        echoerr "${CYAN}TAG_NAME:${NORMAL}%s\n" ${TAG_NAME}
        if [[ "${#_OUT}" -gt 0 ]]; then
            if [[ "$TAG_NAME" == "cfdi:Comprobante" && primero -eq 1 ]]; then
                _TITLE="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $1}' <<< "$_OUT")"
                _REC="$(awk 'BEGIN{FS="\n"; RS="^^"}{print $2}' <<< "$_OUT")"
                primero=0
            else
                if [[ "$TAG_NAME" == "cfdi:Traslado" ]]; then
                    echoerr "${CYAN}#_OUT:${NORMAL}%s\n" ${_OUT}
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
function identificarFacturasUtiles () {
    [[ -z "$1" ]] && { echoerr "Se requiere listado de archivos xml"; return 1; }
    facturasCandidatas="$1"
    facturas=();
    for archivo in ${facturasCandidatas}; do
        _TMP=$(grep -o 'Total="0.00"' $archivo);
        [ $? -ne 0 ] && facturas=( ${facturas[@]} $archivo );
    done;
    for archivo in ${facturas[@]}; do
        _TMP=$(grep 'TipoDeComprobante="N"' $archivo);
        [ $? -ne 0 ] && echo $archivo;
    done
}