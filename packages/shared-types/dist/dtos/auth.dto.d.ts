export interface LoginDto {
    email: string;
    password: string;
}
export interface CheckEmailDto {
    email: string;
}
export interface CheckEmailResponseDto {
    authMethod: 'password' | 'otp' | 'not_found';
}
export interface AuthTokensDto {
    accessToken: string;
    refreshToken: string;
}
export interface JwtPayload {
    sub: string;
    email: string;
    role: string;
    consultantId?: string;
    companyId?: string;
}
export interface MeResponseDto {
    id: string;
    name: string;
    email: string;
    role: string;
}
//# sourceMappingURL=auth.dto.d.ts.map