module vulpes.inputs.sdmx;

import vulpes.inputs.sdmx.client : doRequest;
public import vulpes.inputs.sdmx.services : getCubeDefinition, getCubeDescriptions;

alias getCubeDescriptionsFromSDMXREST = getCubeDescriptions!doRequest;
alias getCubeDefinitionFromSDMXREST = getCubeDefinition!doRequest;