## conversion between spectrum envelop and mel-cepstrum

# TODO(ryuichi) import from MelGeneralizedCepstrums or SPTK
# copied from r9y9/MelGeneralizedCepstrums.jl
function freqt!{T<:FloatingPoint}(wc::AbstractVector{T}, c::AbstractVector{T},
                                  α::FloatingPoint;
                                  prev::Vector{T}=Array(T,length(wc)))
    fill!(wc, zero(T))
    desired_order = length(wc) - 1

    m1 = length(c)-1
    for i=-m1:0
        copy!(prev, wc)
        if desired_order >= 0
            @inbounds wc[1] = c[-i+1] + α*prev[1]
        end
        if desired_order >= 1
            wc[2] = (1.0-α*α)*prev[1] + α*prev[2]
        end
        for m=3:desired_order+1
            @inbounds wc[m] = prev[m-1] + α*(prev[m] - wc[m-1])
        end
    end

    wc
end

function freqt{T<:FloatingPoint}(c::AbstractVector{T}, order::Int,
                                 α::FloatingPoint)
    wc = Array(T, order+1)
    freqt!(wc, c, α)
end

# sp2mc converts power spectrum envelope to mel-cepstrum
# X(ω)² -> cₐ(m)
function sp2mc(powerspec::AbstractVector,
               order::Int,
               α::FloatingPoint; # all-pass constant
               fftlen::Int=(length(powerspec)-1)*2
    )
    # X(ω)² -> log(X(ω)²)
    logperiodogram = log(powerspec)

    # transform log-periodogram to real cepstrum
    # log(X(ω)²) -> c(m)
    c = real(irfft(logperiodogram, fftlen))
    c[1] /= 2.0

    # c(m) -> cₐ(m)
    freqt(c, order, α)
end

# mc2sp converts mel-cepstrum to power spectrum envelope.
# cₐ(m) -> X(ω)²
# equivalent: exp(2real(MelGeneralizedCepstrums.mgc2sp(mc, α, 0.0, fftlen)))
# Note that `MelGeneralizedCepstrums.mgc2sp` returns log magnitude spectrum.
function mc2sp{T}(mc::AbstractVector{T}, α::Float64, fftlen::Int)
    # back to cepstrum from mel-cesptrum
    # cₐ(m) -> c(m)
    c = freqt(mc, fftlen>>1, -α)
    c[1] *= 2.0

    symc = zeros(T, fftlen)
    copy!(symc, c)
    for i=1:length(c)-1
        symc[end-i+1] = symc[i+1]
    end

    # back to power spectrum
    # c(m) -> log(X(ω)²) -> X(ω)²
    exp(real(rfft(symc)))
end

# extend vector to vector transformation for matrix input
for f in [:sp2mc,
          :mc2sp,
          ]
    @eval begin
        function $f(x::AbstractMatrix, args...; kargs...)
            r = $f(x[:, 1], args...; kargs...)
            ret = Array(eltype(r), size(r, 1), size(x, 2))
            for i = 1:length(r)
                @inbounds ret[i, 1] = r[i]
            end
            for i = 2:size(x, 2)
                @inbounds ret[:, i] = $f(x[:, i], args...; kargs...)
            end
            ret
        end
    end
end
