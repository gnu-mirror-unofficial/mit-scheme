#| -*-Scheme-*-

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016,
    2017, 2018 Massachusetts Institute of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.

|#

;;;; UCD property: gc=Mn

;;; Generated from Unicode 9.0.0

(declare (usual-integrations))

(define (char-gc=mark:nonspacing? char)
  (char-in-set? char char-set:gc=mark:nonspacing))

(define-deferred char-set:gc=mark:nonspacing
  (char-set*
   '((768 . 880)
     (1155 . 1160)
     (1425 . 1470)
     1471
     (1473 . 1475)
     (1476 . 1478)
     1479
     (1552 . 1563)
     (1611 . 1632)
     1648
     (1750 . 1757)
     (1759 . 1765)
     (1767 . 1769)
     (1770 . 1774)
     1809
     (1840 . 1867)
     (1958 . 1969)
     (2027 . 2036)
     (2070 . 2074)
     (2075 . 2084)
     (2085 . 2088)
     (2089 . 2094)
     (2137 . 2140)
     (2260 . 2274)
     (2275 . 2307)
     2362
     2364
     (2369 . 2377)
     2381
     (2385 . 2392)
     (2402 . 2404)
     2433
     2492
     (2497 . 2501)
     2509
     (2530 . 2532)
     (2561 . 2563)
     2620
     (2625 . 2627)
     (2631 . 2633)
     (2635 . 2638)
     2641
     (2672 . 2674)
     2677
     (2689 . 2691)
     2748
     (2753 . 2758)
     (2759 . 2761)
     2765
     (2786 . 2788)
     2817
     2876
     2879
     (2881 . 2885)
     2893
     2902
     (2914 . 2916)
     2946
     3008
     3021
     3072
     (3134 . 3137)
     (3142 . 3145)
     (3146 . 3150)
     (3157 . 3159)
     (3170 . 3172)
     3201
     3260
     3263
     3270
     (3276 . 3278)
     (3298 . 3300)
     3329
     (3393 . 3397)
     3405
     (3426 . 3428)
     3530
     (3538 . 3541)
     3542
     3633
     (3636 . 3643)
     (3655 . 3663)
     3761
     (3764 . 3770)
     (3771 . 3773)
     (3784 . 3790)
     (3864 . 3866)
     3893
     3895
     3897
     (3953 . 3967)
     (3968 . 3973)
     (3974 . 3976)
     (3981 . 3992)
     (3993 . 4029)
     4038
     (4141 . 4145)
     (4146 . 4152)
     (4153 . 4155)
     (4157 . 4159)
     (4184 . 4186)
     (4190 . 4193)
     (4209 . 4213)
     4226
     (4229 . 4231)
     4237
     4253
     (4957 . 4960)
     (5906 . 5909)
     (5938 . 5941)
     (5970 . 5972)
     (6002 . 6004)
     (6068 . 6070)
     (6071 . 6078)
     6086
     (6089 . 6100)
     6109
     (6155 . 6158)
     (6277 . 6279)
     6313
     (6432 . 6435)
     (6439 . 6441)
     6450
     (6457 . 6460)
     (6679 . 6681)
     6683
     6742
     (6744 . 6751)
     6752
     6754
     (6757 . 6765)
     (6771 . 6781)
     6783
     (6832 . 6846)
     (6912 . 6916)
     6964
     (6966 . 6971)
     6972
     6978
     (7019 . 7028)
     (7040 . 7042)
     (7074 . 7078)
     (7080 . 7082)
     (7083 . 7086)
     7142
     (7144 . 7146)
     7149
     (7151 . 7154)
     (7212 . 7220)
     (7222 . 7224)
     (7376 . 7379)
     (7380 . 7393)
     (7394 . 7401)
     7405
     7412
     (7416 . 7418)
     (7616 . 7670)
     (7675 . 7680)
     (8400 . 8413)
     8417
     (8421 . 8433)
     (11503 . 11506)
     11647
     (11744 . 11776)
     (12330 . 12334)
     (12441 . 12443)
     42607
     (42612 . 42622)
     (42654 . 42656)
     (42736 . 42738)
     43010
     43014
     43019
     (43045 . 43047)
     (43204 . 43206)
     (43232 . 43250)
     (43302 . 43310)
     (43335 . 43346)
     (43392 . 43395)
     43443
     (43446 . 43450)
     43452
     43493
     (43561 . 43567)
     (43569 . 43571)
     (43573 . 43575)
     43587
     43596
     43644
     43696
     (43698 . 43701)
     (43703 . 43705)
     (43710 . 43712)
     43713
     (43756 . 43758)
     43766
     44005
     44008
     44013
     64286
     (65024 . 65040)
     (65056 . 65072)
     66045
     66272
     (66422 . 66427)
     (68097 . 68100)
     (68101 . 68103)
     (68108 . 68112)
     (68152 . 68155)
     68159
     (68325 . 68327)
     69633
     (69688 . 69703)
     (69759 . 69762)
     (69811 . 69815)
     (69817 . 69819)
     (69888 . 69891)
     (69927 . 69932)
     (69933 . 69941)
     70003
     (70016 . 70018)
     (70070 . 70079)
     (70090 . 70093)
     (70191 . 70194)
     70196
     (70198 . 70200)
     70206
     70367
     (70371 . 70379)
     (70400 . 70402)
     70460
     70464
     (70502 . 70509)
     (70512 . 70517)
     (70712 . 70720)
     (70722 . 70725)
     70726
     (70835 . 70841)
     70842
     (70847 . 70849)
     (70850 . 70852)
     (71090 . 71094)
     (71100 . 71102)
     (71103 . 71105)
     (71132 . 71134)
     (71219 . 71227)
     71229
     (71231 . 71233)
     71339
     71341
     (71344 . 71350)
     71351
     (71453 . 71456)
     (71458 . 71462)
     (71463 . 71468)
     (72752 . 72759)
     (72760 . 72766)
     72767
     (72850 . 72872)
     (72874 . 72881)
     (72882 . 72884)
     (72885 . 72887)
     (92912 . 92917)
     (92976 . 92983)
     (94095 . 94099)
     (113821 . 113823)
     (119143 . 119146)
     (119163 . 119171)
     (119173 . 119180)
     (119210 . 119214)
     (119362 . 119365)
     (121344 . 121399)
     (121403 . 121453)
     121461
     121476
     (121499 . 121504)
     (121505 . 121520)
     (122880 . 122887)
     (122888 . 122905)
     (122907 . 122914)
     (122915 . 122917)
     (122918 . 122923)
     (125136 . 125143)
     (125252 . 125259)
     (917760 . 918000))))
