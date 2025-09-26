const API_ADDRESS = process.env.API_ADDRESS!;
const AUD = API_ADDRESS || process.env.BACKEND_AUDIENCE || "";
const METADATA =
    'http://metadata/computeMetadata/v1/instance/service-accounts/default/identity';

export default {
    API_ADDRESS,
    AUD,
    METADATA
} as const