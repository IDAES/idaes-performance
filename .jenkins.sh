# IDAES Performance Test Suite Jenkins Script
#
# Purpose: Setup the Jenkins testing environment
#          such that it will work with the Sandia systems
#          and have consistent, reproducible behavior.
#
# Usage:   `source ./{DIR}/.jenkins.sh setup

if test -z "$WORKSPACE"; then
    export WORKSPACE=`pwd`
fi

if test "$WORKSPACE" != "`pwd`"; then
    echo "ERROR: pwd is not WORKSPACE"
    echo "   pwd=       `pwd`"
    echo "   WORKSPACE= $WORKSPACE"
    exit 1
fi

MODE="$1"

if test -z "$MODE" -o "$MODE" == setup; then
    # Clean old PYC files and remove any previous virtualenv
    echo "#"
    echo "# Removing python virtual environment"
    echo "#"
    rm -rf ${WORKSPACE}/python
    echo "#"
    echo "# Cleaning out old .pyc and cython files"
    echo "#"
    for EXT in pyc pyx pyd so dylib dll; do
        find ${WORKSPACE}/idaes-pse -name \*.$EXT -delete
    done

    # Set up the local lpython
    echo ""
    echo "#"
    echo "# Setting up virtual environment"
    echo "#"
    virtualenv python $VENV_SYSTEM_PACKAGES --clear || exit 1
    source python/bin/activate
    # Because modules set the PYTHONPATH, we need to make sure that the
    # virtualenv appears first
    LOCAL_SITE_PACKAGES=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`
    export PYTHONPATH="$LOCAL_SITE_PACKAGES:$PYTHONPATH"

    # Set up IDAES checkouts
    echo ""
    # configure the IDAES configuration directory
    echo "#"
    echo "# Installing IDAES-PSE dependencies and modules"
    echo "#"
    pushd "$WORKSPACE/idaes-pse" || exit 1
    pip --no-cache-dir install --progress-bar off -r requirements-dev.txt 
    echo "#"
    echo "# Running 'idaes get-extensions'"
    echo "#"
    idaes get-extensions --extra petsc --verbose
    popd

    # Set up coverage tracking for subprocesses
    if test -z "$DISABLE_COVERAGE"; then
        # Clean up old coverage files
        rm -fv ${WORKSPACE}/idaes-pse/.coverage ${WORKSPACE}/idaes-pse/.coverage.*
        # Set up coverage for this build
        export COVERAGE_PROCESS_START=${WORKSPACE}/coveragerc
        cp ${WORKSPACE}/idaes-pse/.coveragerc ${COVERAGE_PROCESS_START}
        echo "data_file=${WORKSPACE}/idaes-pse/.coverage" \
            >> ${COVERAGE_PROCESS_START}
        echo 'import coverage; coverage.process_startup()' \
            > "${LOCAL_SITE_PACKAGES}/run_coverage_at_startup.pth"
    fi

    # Move into the IDAES directory
    pushd ${WORKSPACE}/idaes-pse || exit 1

    # Set a local IDAES configuration dir within this workspace
    export IDAES_CONFIG_DIR="${WORKSPACE}/config"
    echo ""
    echo "IDAES_CONFIG_DIR=$IDAES_CONFIG_DIR"
    echo ""

    # Print useful version information
    echo ""
    echo "#"
    echo "# Package information:"
    echo "#"
    python --version
    pip --version
    pip show pyomo idaes-pse
    pip list
    #echo "#"
    #echo "# Installed programs:"
    #echo "#"
    #gjh -v || echo "GJH not found"
    #glpsol -v || echo "GLPK not found"
    #cbc -quit || echo "CBC not found"
    #cplex -c quit || echo "CPLEX not found"
    #gurobi_cl --version || echo "GUROBI not found"
    #ipopt -v || echo "IPOPT not found"
    #gams || echo "GAMS not found"

    # Exit ${WORKSPACE}/idaes-pse
    popd
fi

