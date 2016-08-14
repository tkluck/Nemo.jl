###############################################################################
#
#   Poly.jl : Generic multivariate polynomials over rings
#
###############################################################################

export GenMPoly, GenMPolyRing

###############################################################################
#
#   Data type and parent object methods
#
###############################################################################

parent_type{T, S, N}(::Type{GenMPoly{T, S, N}}) = GenMPolyRing{T, S, N}

elem_type{T <: RingElem, S, N}(::GenMPolyRing{T, S, N}) = GenMPoly{T, S, N}

vars(a::GenMPolyRing) = a.S

function gens{T <:RingElem, S, N}(a::GenMPolyRing{T, S, N})
   if S == :lex
      return [a([base_ring(a)(1)], [tuple([UInt(i == j) for j in 1:a.num_vars]...)])
           for i in 1:a.num_vars]
   elseif S == :deglex
      return [a([base_ring(a)(1)], [tuple(UInt(1), [UInt(i == j) for j in 1:a.num_vars]...)])
           for i in 1:a.num_vars]
   elseif S == :revlex
      return [a([base_ring(a)(1)], [tuple([UInt(N - i + 1 == j) for j in 1:a.num_vars]...)])
           for i in 1:a.num_vars]
   else # S == :degrevlex
      return [a([base_ring(a)(1)], [tuple(UInt(1), [UInt(N - i == j) for j in 1:a.num_vars]...)])
           for i in 1:a.num_vars]
   end
end

###############################################################################
#
#   Monomial operations
#
###############################################################################

zero{N}(::Type{NTuple{N, UInt}}) = ntuple(i -> 0, Val{N})

function +{N}(a::NTuple{N, UInt}, b::NTuple{N, UInt})
   return ntuple(i -> a[i] + b[i], Val{N})
end

function *{N}(a::NTuple{N, UInt}, n::Int)
   return ntuple(i -> a[i]*reinterpret(UInt, n), Val{N})
end

function cmp{T <: RingElem, S, N}(a::NTuple{N, UInt},
                                  b::NTuple{N, UInt}, R::GenMPolyRing{T, S, N})
   i = 1
   while i < N && a[i] == b[i]
      i += 1
   end
   return reinterpret(Int, a[i] - b[i])
end

###############################################################################
#
#   Basic manipulation
#
###############################################################################

function coeff(x::GenMPoly, i::Int)
   i < 0 && throw(DomainError())
   return x.coeffs[i + 1]
end

num_vars(x::GenMPoly) = parent(x).num_vars

function normalise(a::GenMPoly, n::Int)
   while n > 0 && iszero(a.coeffs[n]) 
      n -= 1
   end
   return n
end

###############################################################################
#
#   String I/O
#
###############################################################################

function show{T <: RingElem, S, N}(io::IO, x::GenMPoly{T, S, N})
    len = length(x)
    U = [string(x) for x in vars(parent(x))]
    if len == 0
      print(io, base_ring(x)(0))
    else
      for i = 1:len
        c = coeff(x, len - i)
        bracket = needs_parentheses(c)
        if i != 1 && !is_negative(c)
          print(io, "+")
        end
        X = x.exps[len - i + 1]
        if (S == :revlex || S == :degrevlex)
           X = reverse(X)
        end
        if !isone(c) && (c != -1 || show_minus_one(typeof(c)))
          if bracket
            print(io, "(")
          end
          show(io, c)
          if bracket
            print(io, ")")
          end
          if c != 1 && !(c == -1 && !show_minus_one(typeof(c))) && X != zero(NTuple{N, UInt})
             print(io, "*")
          end
        end
        if c == -1 && !show_minus_one(typeof(c))
          print(io, "-")
        end
        d = (S == :deglex) ? 1 : 0
        if X == zero(NTuple{N, UInt})
          if c == 1
             print(io, c)
          elseif c == -1 && !show_minus_one(typeof(c))
             print(io, 1)
          end
        end
        fst = true
        for j = 1:num_vars(x)
          n = reinterpret(Int, X[j + d])
          if n != 0
            if fst
               print(io, U[j])
               fst = false
            else
               print(io, "*", U[j])
            end
            if n != 1
              print(io, "^", n)
            end
          end
        end      
    end
  end
end

function show(io::IO, p::GenMPolyRing)
   const max_vars = 5 # largest number of variables to print
   n = p.num_vars
   print(io, "Multivariate Polynomial Ring in ")
   if n > max_vars
      print(io, p.num_vars)
      print(io, " variables ")
   end
   for i = 1:min(n - 1, max_vars - 1)
      print(io, string(p.S[i]), ", ")
   end
   if n > max_vars
      print(io, "..., ")
   end
   print(io, string(p.S[n]))
   print(io, " over ")
   show(io, base_ring(p))
end

###############################################################################
#
#   Arithmetic functions
#
###############################################################################

function -{T <: RingElem, S, N}(a::GenMPoly{T, S, N})
   r = parent(a)()
   fit!(r, length(a))
   for i = 1:length(a)
      r.coeffs[i] = -a.coeffs[i]
      r.exps[i] = a.exps[i]
   end
   r.length = a.length
   return r
end

function +{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::GenMPoly{T, S, N})
   par = parent(a)
   r = par()
   fit!(r, length(a) + length(b))
   i = 1
   j = 1
   k = 1
   while i <= length(a) && j <= length(b)
      cmpexp = cmp(a.exps[i], b.exps[j], par)
      if cmpexp < 0
         r.coeffs[k] = a.coeffs[i]
         r.exps[k] = a.exps[i]
         i += 1
      elseif cmpexp == 0
         c = a.coeffs[i] + b.coeffs[j]
         if c != 0
            r.coeffs[k] = c
            r.exps[k] = a.exps[i]
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         r.coeffs[k] = b.coeffs[j]
         r.exps[k] = b.exps[j]
         j += 1
      end
      k += 1
   end
   while i <= length(a)
      r.coeffs[k] = a.coeffs[i]
      r.exps[k] = a.exps[i]
      i += 1
      k += 1
   end
   while j <= length(b)
      r.coeffs[k] = b.coeffs[j]
      r.exps[k] = b.exps[j]
      j += 1
      k += 1
   end
   r.length = k - 1
   return r
end

function -{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::GenMPoly{T, S, N})
   par = parent(a)
   r = par()
   fit!(r, length(a) + length(b))
   i = 1
   j = 1
   k = 1
   while i <= length(a) && j <= length(b)
      cmpexp = cmp(a.exps[i], b.exps[j], par)
      if cmpexp < 0
         r.coeffs[k] = a.coeffs[i]
         r.exps[k] = a.exps[i]
         i += 1
      elseif cmpexp == 0
         c = a.coeffs[i] - b.coeffs[j]
         if c != 0
            r.coeffs[k] = c
            r.exps[k] = a.exps[i]
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         r.coeffs[k] = -b.coeffs[j]
         r.exps[k] = b.exps[j]
         j += 1
      end
      k += 1
   end
   while i <= length(a)
      r.coeffs[k] = a.coeffs[i]
      r.exps[k] = a.exps[i]
      i += 1
      k += 1
   end
   while j <= length(b)
      r.coeffs[k] = -b.coeffs[j]
      r.exps[k] = b.exps[j]
      j += 1
      k += 1
   end
   r.length = k - 1
   return r
end

function do_copy{T <: RingElem, S, N}(Ac::Array{T, 1}, Bc::Array{T, 1},
               Ae::Array{NTuple{N, UInt}, 1}, Be::Array{NTuple{N, UInt}, 1}, 
        s1::Int, r::Int, n1::Int, par::GenMPolyRing{T, S, N})
   for i = 1:n1
      Bc[r + i] = Ac[s1 + i]
      Be[r + i] = Ae[s1 + i]
   end
   return n1
end

function do_merge{T <: RingElem, S, N}(Ac::Array{T, 1}, Bc::Array{T, 1},
               Ae::Array{NTuple{N, UInt}, 1}, Be::Array{NTuple{N, UInt}, 1}, 
        s1::Int, s2::Int, r::Int, n1::Int, n2::Int, par::GenMPolyRing{T, S, N})
   i = 1
   j = 1
   k = 1
   while i <= n1 && j <= n2
      cmpexp = cmp(Ae[s1 + i], Ae[s2 + j], par)
      if cmpexp < 0
         Bc[r + k] = Ac[s1 + i]
         Be[r + k] = Ae[s1 + i]
         i += 1
      elseif cmpexp == 0
         addeq!(Ac[s1 + i], Ac[s2 + j])
         if Ac[s1 + i] != 0
            Bc[r + k] = Ac[s1 + i]
            Be[r + k] = Ae[s1 + i]
         else
            k -= 1
         end
         i += 1
         j += 1
      else
         Bc[r + k] = Ac[s2 + j]
         Be[r + k] = Ae[s2 + j]
         j += 1
      end
      k += 1
   end
   while i <= n1
      Bc[r + k] = Ac[s1 + i]
      Be[r + k] = Ae[s1 + i]
      i += 1
      k += 1
   end
   while j <= n2
      Bc[r + k] = Ac[s2 + j]
      Be[r + k] = Ae[s2 + j]
      j += 1
      k += 1
   end
   return k - 1
end

function *{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::GenMPoly{T, S, N})
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   if m == 0 || n == 0
      return par()
   end
   a_alloc = max(m, n) + n
   b_alloc = max(m, n) + n
   Ac = Array(T, a_alloc)
   Bc = Array(T, b_alloc)
   Ae = Array(NTuple{N, UInt}, a_alloc)
   Be = Array(NTuple{N, UInt}, b_alloc)
   Am = Array(Int, 64) # 64 is upper bound on max(log m, log n)
   Bm = Array(Int, 64) # ... num polys merged (power of 2)
   Ai = Array(Int, 64) # index of polys in A minus 1
   Bi = Array(Int, 64) # index of polys in B minus 1
   An = Array(Int, 64) # lengths of polys in A
   Bn = Array(Int, 64) # lengths of polys in B
   Anum = 0 # number of polys in A
   Bnum = 0 # number of polys in B
   sa = 0 # number of used locations in A
   sb = 0 # number of used locations in B
   for i = 1:m # loop over monomials in a
      # check space
      if sa + n > a_alloc
         a_alloc = max(2*a_alloc, sa + n)
         resize!(Ac, a_alloc)
         resize!(Ae, a_alloc)
      end
      # compute monomial by polynomial product and store in A
      c = a.coeffs[i]
      d = a.exps[i]
      k = 1
      for j = 1:n
         s = Ac[sa + k] = c*b.coeffs[j]
         if s != 0
            Ae[sa + k] = d + b.exps[j]
            k += 1
         end
      end
      k -= 1
      Anum += 1
      Am[Anum] = 1
      Ai[Anum] = sa
      An[Anum] = k
      sa += k
      # merge similar sized polynomials from A to B...
      while Anum > 1 && (Am[Anum] == Am[Anum - 1])
         # check space
         want = sb + An[Anum] + An[Anum - 1]
         if want > b_alloc
            b_alloc = max(2*b_alloc, want)
            resize!(Bc, b_alloc)
            resize!(Be, b_alloc)            
         end
         # do merge to B
         k = do_merge(Ac, Bc, Ae, Be, Ai[Anum - 1], Ai[Anum], 
                                               sb, An[Anum - 1], An[Anum], par)
         Bnum += 1
         Bm[Bnum] = 2*Am[Anum]
         Bi[Bnum] = sb
         Bn[Bnum] = k
         sb += k
         sa -= An[Anum]
         sa -= An[Anum - 1]
         Anum -= 2
         # merge similar sized polynomials from B to A...
         if Bnum > 1 && (Bm[Bnum] == Bm[Bnum - 1])
            # check space
            want = sa + Bn[Bnum] + Bn[Bnum - 1]
            if want > a_alloc
               a_alloc = max(2*a_alloc, want)
               resize!(Ac, a_alloc)
               resize!(Ae, a_alloc)            
            end
            # do merge to A
            k = do_merge(Bc, Ac, Be, Ae, Bi[Bnum - 1], Bi[Bnum], 
                                               sa, Bn[Bnum - 1], Bn[Bnum], par)
            Anum += 1
            Am[Anum] = 2*Bm[Bnum]
            Ai[Anum] = sa
            An[Anum] = k
            sa += k
            sb -= Bn[Bnum]
            sb -= Bn[Bnum - 1]
            Bnum -= 2
         end
      end
   end 
   # Add all irregular sized polynomials together
   while Anum + Bnum > 1
      # Find the smallest two polynomials
      if Anum == 0 || Bnum == 0
         c1 = c2 = (Anum == 0) ? 2 : 1
      elseif Anum + Bnum == 2
         c1 = (Am[Anum] < Bm[Bnum]) ? 1 : 2
         c2 = 3 - c1
      elseif Am[Anum] < Bm[Bnum]
         c1 = 1
         c2 = (Anum == 1 || (Bnum > 1 && Bm[Bnum] < Am[Anum - 1])) ? 2 : 1
      else
         c1 = 2
         c2 = (Bnum == 1 || (Anum > 1 && Am[Anum] < Bm[Bnum - 1])) ? 1 : 2
      end
      # If both polys are on side A, merge to side B
      if c1 == 1 && c2 == 1
         # check space
         want = sb + An[Anum] + An[Anum - 1]
         if want > b_alloc
            b_alloc = max(2*b_alloc, want)
            resize!(Bc, b_alloc)
            resize!(Be, b_alloc)            
         end
         # do merge to B
         k = do_merge(Ac, Bc, Ae, Be, Ai[Anum - 1], Ai[Anum], 
                                               sb, An[Anum - 1], An[Anum], par)
         Bnum += 1
         Bm[Bnum] = 2*Am[Anum - 1]
         Bi[Bnum] = sb
         Bn[Bnum] = k
         sb += k
         sa -= An[Anum]
         sa -= An[Anum - 1]
         Anum -= 2
      # If both polys are on side B, merge to side A
      elseif c1 == 2 && c2 == 2
         # check space
         want = sa + Bn[Bnum] + Bn[Bnum - 1]
         if want > a_alloc
            a_alloc = max(2*a_alloc, want)
            resize!(Ac, a_alloc)
            resize!(Ae, a_alloc)            
         end
         # do merge to A
         k = do_merge(Bc, Ac, Be, Ae, Bi[Bnum - 1], Bi[Bnum], 
                                            sa, Bn[Bnum - 1], Bn[Bnum], par)
         Anum += 1
         Am[Anum] = 2*Bm[Bnum - 1]
         Ai[Anum] = sa
         An[Anum] = k
         sa += k
         sb -= Bn[Bnum]
         sb -= Bn[Bnum - 1]
         Bnum -= 2
      # Polys are on different sides, move from smallest side to largest
      else
         # smallest poly on side A, move to B
         if c1 == 1
            # check space
            want = sb + An[Anum]
            if want > b_alloc
               b_alloc = max(2*b_alloc, want)
               resize!(Bc, b_alloc)
               resize!(Be, b_alloc)            
            end
            # do copy to B
            k = do_copy(Ac, Bc, Ae, Be, Ai[Anum], sb, An[Anum], par)
            Bnum += 1
            Bm[Bnum] = Am[Anum]
            Bi[Bnum] = sb
            Bn[Bnum] = k
            sb += k
            sa -= An[Anum]
            Anum -= 1
         # smallest poly on side B, move to A
         else
            # check space
            want = sa + Bn[Bnum]
            if want > a_alloc
               a_alloc = max(2*a_alloc, want)
               resize!(Ac, a_alloc)
               resize!(Ae, a_alloc)            
            end
            # do copy to A
            k = do_copy(Bc, Ac, Be, Ae, Bi[Bnum], sa, Bn[Bnum], par)
            Anum += 1
            Am[Anum] = Bm[Bnum]
            Ai[Anum] = sa
            An[Anum] = k
            sa += k
            sb -= Bn[Bnum]
            Bnum -= 1
         end
      end
   end
   # Result is on side A
   if Anum == 1
      resize!(Ac, An[1])
      resize!(Ae, An[1])
      return parent(a)(Ac, Ae)
   # Result is on side B
   else
      resize!(Bc, Bn[1])
      resize!(Be, Bn[1])
      return parent(a)(Bc, Be)
   end
end

function isless{N}(a::Tuple{NTuple{N, UInt}, Int, Int}, b::Tuple{NTuple{N, UInt}, Int, Int})
   return a[1] < b[1]
end

function =={N}(a::Tuple{NTuple{N, UInt}, Int, Int}, b::Tuple{NTuple{N, UInt}, Int, Int})
   return a[1] == b[1]
end

function mul_johnson{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::GenMPoly{T, S, N})
   par = parent(a)
   R = base_ring(par)
   m = length(a)
   n = length(b)
   if m == 0 || n == 0
      return par()
   end
   H = Array(Tuple{NTuple{N, UInt}, Int, Int}, 0)
   # set up heap
   for i = 1:m
      Collections.heappush!(H, (a.exps[i] + b.exps[1], i, 1))
   end
   r_alloc = max(m, n) + n
   Rc = Array(T, r_alloc)
   Re = Array(NTuple{N, UInt}, r_alloc)
   k = 0
   c = R()
   while length(H) > 0
      exp, i, j = Collections.heappop!(H)
      if k > 0 && exp == Re[k]
         mul!(c, a.coeffs[i], b.coeffs[j])
         addeq!(Rc[k], c)
      else
         k += 1
         if k > r_alloc
            r_alloc *= 2
            resize!(Rc, r_alloc)
            resize!(Re, r_alloc)
         end
         Rc[k] = a.coeffs[i]*b.coeffs[j]
         Re[k] = exp
      end
      if j < n
         Collections.heappush!(H, (a.exps[i] + b.exps[j + 1], i, j + 1))
      end
   end
   resize!(Rc, k)
   resize!(Re, k)
   return parent(a)(Rc, Re)
end

###############################################################################
#
#   Ad hoc arithmetic functions
#
###############################################################################

function *{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, n::Integer)
   r = parent(a)()
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = a.coeffs[i]*n
      if c != 0
         r.coeffs[j] = c 
         r.exps[j] = a.exps[i]
         j += 1
      end
   end
   r.length = j - 1
   return r
end

function *{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, n::fmpz)
   r = parent(a)()
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = a.coeffs[i]*n
      if c != 0
         r.coeffs[j] = c 
         r.exps[j] = a.exps[i]
         j += 1
      end
   end
   r.length = j - 1
   return r
end

function *{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, n::T)
   r = parent(a)()
   fit!(r, length(a))
   j = 1
   for i = 1:length(a)
      c = a.coeffs[i]*n
      if c != 0
         r.coeffs[j] = c 
         r.exps[j] = a.exps[i]
         j += 1
      end
   end
   r.length = j - 1
   return r
end

*{T <: RingElem, S, N}(n::Integer, a::GenMPoly{T, S, N}) = a*n

*{T <: RingElem, S, N}(n::fmpz, a::GenMPoly{T, S, N}) = a*n

*{T <: RingElem, S, N}(n::T, a::GenMPoly{T, S, N}) = a*n

+{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::T) = a + parent(a)(b)

+{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::Integer) = a + parent(a)(b)

+{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::fmpz) = a + parent(a)(b)

-{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::T) = a - parent(a)(b)

-{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::Integer) = a - parent(a)(b)

-{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, b::fmpz) = a - parent(a)(b)

+{T <: RingElem, S, N}(a::T, b::GenMPoly{T, S, N}) = parent(b)(a) + b

+{T <: RingElem, S, N}(a::Integer, b::GenMPoly{T, S, N}) = parent(b)(a) + b

+{T <: RingElem, S, N}(a::fmpz, b::GenMPoly{T, S, N}) = parent(b)(a) + b

-{T <: RingElem, S, N}(a::T, b::GenMPoly{T, S, N}) = parent(b)(a) - b

-{T <: RingElem, S, N}(a::Integer, b::GenMPoly{T, S, N}) = parent(b)(a) - b

-{T <: RingElem, S, N}(a::fmpz, b::GenMPoly{T, S, N}) = parent(b)(a) - b

###############################################################################
#
#   Powering
#
###############################################################################

function ^(a::GenMPoly, b::Int)
   b < 0 && throw(DomainError())
   # special case powers of x for constructing polynomials efficiently
   if length(a) == 0
      return parent(a)()
   elseif length(a) == 1
      return parent(a)([coeff(a, 0)^b], [a.exps[1]*b])
   elseif b == 0
      return parent(a)(1)
   else
      z = a
      for i = 1:b - 1
         z *= a
      end
      return z
   end
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function fit!{T <: RingElem, S, N}(a::GenMPoly{T, S, N}, n::Int)
   if length(a.coeffs) < n
      resize!(a.coeffs, n)
      resize!(a.exps, n)
   end
end

###############################################################################
#
#   Parent object call overload
#
###############################################################################

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N}, b::RingElem)
   return a(base_ring(a)(b), a.vars)
end

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N})
   z = GenMPoly{T, S, N}()
   z.parent = a
   return z
end

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N}, b::Integer)
   z = GenMPoly{T, S, N}(base_ring(a)(b))
   z.parent = a
   return z
end

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N}, b::T)
   parent(b) != base_ring(a) && error("Unable to coerce to polynomial")
   z = GenMPoly{T, S, N}(b)
   z.parent = a
   return z
end

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N}, b::PolyElem{T})
   parent(b) != a && error("Unable to coerce polynomial")
   return b
end

function Base.call{T <: RingElem, S, N}(a::GenMPolyRing{T, S, N}, b::Array{T, 1}, m::Array{NTuple{N, UInt}, 1})
   if length(b) > 0
      parent(b[1]) != base_ring(a) && error("Unable to coerce to polynomial")
   end
   z = GenMPoly{T, S, N}(b, m)
   z.parent = a
   return z
end

###############################################################################
#
#   PolynomialRing constructor
#
###############################################################################

doc"""
    PolynomialRing(R::Ring, s::Array{String, 1}; cached::Bool = true, S::Symbol = :lex)
> Given a base ring `R` and an array of strings `s` specifying how the
> generators (variables) should be printed, return a tuple `S, x1, x2, ...`
> representing the new polynomial ring $T = R[x1, x2, ...]$ and the generators
> $x1, x2, ...$ of the polynomial ring. By default the parent object `T` will
> depend only on `R` and `x1, x2, ...` and will be cached. Setting the optional
> argument `cached` to `false` will prevent the parent object `T` from being
> cached. `S` is a symbol corresponding to the ordering of the polynomial and
> can be one of `:lex`, `:deglex`, `:revlex` or `:degrevlex`.
"""
function PolynomialRing(R::Ring, s::Array{String, 1}; cached::Bool = true, ordering::Symbol = :lex)
   U = [Symbol(x) for x in s]
   T = elem_type(R)
   N = (ordering == :deglex || ordering == :degrevlex) ? length(U) + 1 : length(U)
   parent_obj = GenMPolyRing{T, ordering, N}(R, U, cached)

   return tuple(parent_obj, gens(parent_obj)...)
end