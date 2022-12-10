#!/bin/zsh -f
set -eu

# Guide:
# Just use ./build.zsh to compile to PDF.
# Use +f to force a recompile.
# Modify DOC to change the relevant tex file.
# Modify TMP & BIB to use different temporary storage.
# Use "./build.zsh -c" to clean up

# set -x

DEFAULTDOC="report"
COMPILER="pdflatex"

NEEDBIB="yes"
RECOMPILE="yes"
CLEAN="no"
HELP="no"

TMP=.latex.out
BIB_OUT=.bibtex.out

VERBOSE=0

while getopts "bcfv" OPTION
do
  case ${OPTION} in
     c) CLEAN="yes"       ;;
     f) RECOMPILE="yes"   ;;
     h) HELP="yes"        ;;
     b) NEEDBIB="no"      ;;
    +b) NEEDBIB="yes"     ;;
     v)  : $((VERBOSE++)) ;;
     *) return 1          ;;
  esac
done
shift $(( OPTIND-1 ))
if (( ${#*} == 1 ))
then
  DOC=$1
fi

crash()
{
  print ${*}
  exit 1
}

if [[ ${HELP} == "yes" ]]
then
  print "See the notes at the top of build.zsh"
  return 0
fi

(( ${+DOC} ))     || DOC=${DEFAULTDOC}

V=""
(( VERBOSE > 0 )) && V="-v"
(( VERBOSE > 1 )) && set -x

# Check if file $1 is uptodate wrt $2
# $1 is uptodate if it exists and is newer than $2
# If $2 does not exist, crash
uptodate()
{
  if (( ${#} < 2 ))
  then
    print "uptodate: Need at least 2 args!"
    return 1
  fi

  local OPTION
  local VERBOSE=0
  while getopts "v" OPTION
  do
    case ${OPTION}
      in
      v)
        (( VERBOSE++ )) ;;
    esac
  done
  shift $(( OPTIND-1 ))

  if (( VERBOSE > 1 ))
  then
    set -x
  fi

  local TARGET=$1
  shift
  local PREREQS
  PREREQS=( ${*} )

  local f
  for f in ${PREREQS}
  do
    if [[ ! -f ${f} ]]
    then
      (( VERBOSE )) && print "not found: ${f}"
      return 1
    fi
  done

  if [[ ! -f ${TARGET} ]]
  then
    print "does not exist: ${TARGET}"
    return 1
  fi

  local CODE
  for f in ${PREREQS}
  do
    [[ ${TARGET} -nt ${f} ]]
    CODE=${?}
    if (( ${CODE} == 0 ))
    then
      ((VERBOSE)) && print "${TARGET} : ${f} is uptodate"
    else
      ((VERBOSE)) && print "${TARGET} : ${f} is not uptodate"
      return ${CODE}
    fi
  done
  return ${CODE}
}

zclm()
# Select columns from input without awk
{
  local L
  local -Z c
  local A C i
  C=( ${*} )
  while read L
  do
    A=( $( print -- ${L} ) )
    N=${#C}
    for (( i=1 ; i<=N ; i++ ))
    do
      c=${C[i]}
      print -n "${A[c]}"
      (( i < N )) && print -n " "
    done
    printf "\n"
  done
  return 0
}

clean()
{
  local t
  setopt NULL_GLOB
  t=(  core* *.aux *.bbl *.blg *.dvi *.latex* *.log )
  t+=( *.toc *.lot *.lof .*.out )
  t+=( ${DOC}.pdf *.ps )
  if [[ ${#t} > 0 ]]
  then
    rm -fv ${t}
  else
    print "Nothing to clean."
  fi
  return 0
}

scan()
{
  [[ $1 == "" ]] && return
  typeset -g -a $1
  local i=1
  while read T
  do
    eval "${1}[${i}]='${T}'"
    (( i++ ))
  done
}

shoot()
# print out an array loaded by scan()
{
  local i
  local N
  N=$( eval print '${#'$1'}' )
    # print N $N
  for (( i=1 ; i <= N ; i++ ))
  do
    eval print -- "$"${1}"["${i}"]"
  done
}

# Verbose operation
@()
{
  print
  print XXX ${*}
  print
  ${*}
}

check_bib_missing()
{
  awk '$0 ~ /Warn.*database entry/ { gsub(/\\"/, "", $8); print "No entry for: " $8; }'
}

biblio()
{
  if [[ -f ${DOC}.bbl ]]
  then
    if ! uptodate ${V} ${DOC}.bbl ${DOC}.bib
    then
      rm ${V} ${DOC}.bbl
    fi
  fi
  if { bibtex ${DOC} >& ${BIB_OUT} }
   then
    printf "."
    ((VERBOSE)) && printf "\n"
    ${COMPILER} ${DOC} >& /dev/null
    printf "."
    ((VERBOSE)) && printf "\n"
    ${COMPILER} ${DOC} >& ${TMP}
    printf "."
    ((VERBOSE)) && printf "\n"
    check_bib_missing < ${BIB_OUT} | scan WARNS
    if (( ${#WARNS} > 0 ))
      then
      printf "\n"
      print "Bibtex:"
      shoot WARNS
    fi
  else
    printf "\n"
    cat ${BIB_OUT}
  fi
}

check_imgs()
{
  grep -h includegraphics *.tex | scan A
  IMGS=()
  for line in ${A}
  do
    PDF=( $( print ${${line/'{'/ }/'}'/ } ) )
    PDF=${PDF[2]}.pdf
    IMGS+=${PDF}
  done
  if (( ${#IMGS} > 0 ))
  then
    uptodate ${V} ${DOC}.pdf ${IMGS} || RECOMPILE="yes"
  fi
}

check_code()
{
  # Suppress boxes around code:
  export NO_BOX=1

  CODES=( $( grep -h "input code" **/*.tex || true | zclm 2 ) )
  for C in ${CODES}
  do
    # Handle input file that may or may not have suffix .tex
    SRC=${C%.tex}
    C=${C}.tex
    # SRC file does not need to exist:
    [[ -f ${SRC} ]] || continue
    if ! uptodate ${V} ${C} ${SRC} code/script2tex.pl
    then
      print "generating: ${SRC}.tex"
      perl code/script2tex.pl ${SRC} > ${C}
    fi
  done
  if (( ${#CODES} > 0 ))
  then
    uptodate ${V} ${DOC}.pdf ${CODES} || RECOMPILE="yes"
  fi
}

report_known_errors()
{
  egrep '^l.|^!|argument' ${TMP}
  grep "made by different executable version" ${TMP}
  grep "Fatal format file error" ${TMP}
}

[[ ${CLEAN} == "yes" ]] && clean && return

(( ${#DOC} > 0 )) || crash "Must specify LaTeX file!"

check_code
if [[ ${RECOMPILE} == "no" ]]
then
  [[ -f ${DOC}.pdf ]] || RECOMPILE="yes"
fi
if [[ ${RECOMPILE} == "no" ]]
then
  [[ -f error ]] && RECOMPILE="yes"
fi
if [[ ${RECOMPILE} == "no" ]]
then
  uptodate ${V} ${DOC}.pdf ${DOC}.tex || \
    RECOMPILE="yes"
fi
if [[ ${RECOMPILE} == "no" ]]
then
  check_imgs
fi

CODE=0
if [[ ${RECOMPILE} == "yes" ]]
 then
  ((VERBOSE)) && print "LaTeX ..."
  if { ${COMPILER} --interaction nonstopmode ${DOC} >& ${TMP} }
   then
    printf "OK"
    ((VERBOSE)) && printf "\n"
    rm -f error
    [[ ${NEEDBIB} == "yes" ]] && biblio
  else
    printf "Error! \n"
    report_known_errors
    touch error
    CODE=1
  fi
fi

printf "\n"

set +e # Ignore grep none-selected errors

grep --color=always "LaTeX Warning:" ${TMP} | \
  grep -v "float specifier"                 | \
  grep -v "Citation"

grep "LaTeX Warning: Citation" ${TMP} | \
  awk '{ print $0;
         C = substr($4, 2, length($4)-2);
         cmd = "grep -n --color=always " C " **/*.tex";
         # print(cmd);
         system(cmd);
       }'

return ${CODE}
